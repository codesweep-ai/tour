# simple-tools-demo

This repo serves as a simple demonstration of how to use the codesweep tools in
a project of your own. It pins every tool it uses, and it runs a real campaign
end to end so that you can see the whole cycle work.

## Before you start

You need node and npm for the dev-mode tools, and a Go toolchain for the use-mode
ones. The members boot on podman with Firecracker, so this host needs podman and a
writable `/dev/kvm`. Tailscale needs to be up if you want the app and the reports on
a URL you can open from another machine.

You also need a Fireworks key on disk at `~/.cs-keys/fireworks`, with mode `0600`.
An exported environment variable is not enough, because the demo lends the key and
the lender reads a host file. `make setup` ends by saying whether that file is there,
and prints the three commands that write it.

## Which sequence do you want

```bash
make setup           # you just cloned this, and want the tools
make demo-validate   # prove the campaign is wired, before it costs anything
make demo            # run it end to end, which takes about half an hour
make demo-watch      # in a second terminal, follow progress and health
make show-reports    # read the dispatch page and the trajectories
make demo-clean      # you are done, and want the demo and its artefacts gone
make demo-clean clean-all   # you want this directory back to nothing
```

The check before the run matters, because `make demo` boots three members and spends
real tokens. `make demo-validate` reads the profile, the mission and the three briefs
and costs nothing, so a typo in a brief is found the cheap way.

The tools are only half of what the demo needs. It lends a Fireworks key from
`~/.cs-keys/fireworks`, and `make setup` ends by saying whether that file is there
and how to write it. Lending reads a host file rather than an environment variable,
so an exported key on its own is not enough.

Run `make` on its own to see this list again, along with every command and a one line
description of each.

## Running it by hand

Each command below prints something you can check, so you can tell a working step
from a silent one.

**`make setup`** ends with the credential line and the derived versions. Look for
`credential  ~/.cs-keys/fireworks is present`, and a `cs-sandbox` version that says
`named by campaign`. It takes a couple of minutes, mostly fetching binaries.

**`make demo-validate`** prints `valid CampaignProfile` with a digest, then
`mission <digest>, 3 role briefs`. It costs nothing and takes a second.

**`make demo-start`** boots three members and then runs the readback. It prints one
line per member, and each one ends with `(confirmed by the answering turn)`. That
phrase matters: it means the model each member answered on is the model
the profile declared. It takes a few minutes, and it is where the run spends first.

**`make demo-watch`** belongs in a second terminal. It prints one line per member on
every look, and new orchestrator claims as they appear. An orchestrator can work for
many minutes between claims, so silence there is normal and the watcher says so.

**`make demo-fetch`** prints `tree differs from base (real changes present)` and a
commit count. It fails when the orchestrator branch matches its base, because that
means the campaign delivered nothing whatever it reported.

**`make demo-archive`** prints the list of `INCOMPLETE` markers, and that list should
be empty. Anything it could not collect leaves a marker rather than failing quietly.

**`make demo-dispatch-page`** and **`make demo-trajectories`** each print where they
wrote. The trajectory step also prints how many traces and events it found.

**`make show-app`** and **`make show-reports`** print URLs on your Tailscale address.

The trajectory index lists the members by name, and each name opens that member's own
sessions. A session is titled by its dispatch and never by its member, so the index is
how you tell the orchestrator from the developer and from qa.

Reports never carry over from one run to the next. `make demo-start` moves the previous
archive, dispatch page and trajectories into `.work/runs`, under the time of the move.
`make show-reports` also refuses a page that is older than the archive beside it.

The whole cycle took about half an hour on the run this README was written against.
Most of that was the orchestrator reviewing the developer's work and checking the
built interface itself.

## Two kinds of tool

This project is in use mode for every tool it touches. It edits none of them, so the
dev-mode and use-mode split of the wider fleet does not divide anything here. Dev
mode is what you are in when you open one of the tool repositories itself.

The split that matters inside this repo is a different one. It is when a tool runs,
and how it is pinned.

**Tools that check this repo** are `cs-lint` and `cs-ledger`. They read the files in
this directory and report whether the documents and the ledger are in order. Both are
published to npm. The pins sit in `package.json`, the exact versions are locked in
`package-lock.json`, and the binaries run from `node_modules/.bin`. They are dev dependencies
in the ordinary npm sense of the phrase.

**The tool this repo runs** is `cs-campaign`, along with the programs it needs at run
time. None of them is published to npm, and none has a tagged release, so this repo
installs them from the Go module proxy into a local `tools` directory. That needs a Go
toolchain on the machine that runs `make setup`.

You should always invoke a tool through a make target rather than by typing its
bare name. The reason is that a bare name finds whatever copy happens to sit on
your `PATH`, which is usually a different version from the one this repo pins.
Each make target names its tool exactly once, so the pin cannot be bypassed.

## How the versions chain together

You choose one version, `CAMPAIGN_VERSION`, and the `Makefile` derives the rest.
It reads that campaign's own `go.mod` from the module proxy, and it installs the
`cs-sandbox`, `cs-tracer` and `cs-vcr` versions named there. This keeps the
chain consistent without asking you to track four numbers.

Only one of those versions has to agree at runtime, and that is `cs-sandbox`.
Campaign executes it on every run, and `make doctor` fails when the two
disagree. The sandbox image carries its own copy of `cs-vcr` inside it. Campaign
never executes `cs-lint`, `cs-ledger` or `cs-tracer` during a run, so `make
doctor` reports those as informational.

## The campaign

The campaign in `campaign/hello` runs three members: an orchestrator, a developer
and a qa role. It exercises every stage of the cycle, and it ends with a served
application rather than a report claiming one exists.

The work divides the way you would divide it yourself. The orchestrator designs the
interface first and commits that design as `DESIGN.md`, so both agents build against
one artefact rather than against prose in their own briefs. The developer builds what
the design says, and the qa role checks the result against it. The orchestrator checks
both of them itself, merges the verified work into its own branch, and serves the
result. A served interface is the deliverable.

The mission names the outcome and leaves the design open: a greeting whose colour
changes when you click a button. What the greeting says, which colours, and how it
is laid out are the orchestrator's choices.

The Fireworks key is lent to each member rather than copied into it. Lending
reads the key from `~/.cs-keys/fireworks`, so you need to create that file once
with mode `0600`. An environment variable cannot be lent, because the lender
reads a file on the host instead of an environment.

Two stopping commands sit beside `make demo-clean`, for when you want less than a
full discard. Run `make demo-stop` to stop serving while leaving the members alive,
and `make demo-destroy` to drop the members while keeping the archive.

The stages run one at a time too, in this order: `make demo-start`,
`make demo-wait`, `make demo-fetch`, `make demo-archive`,
`make demo-dispatch-page`, `make demo-trajectories` and `make show-app`.

### When the readback misses its bound

A readback is bounded at 15 minutes per member, and no flag raises it. Under host
load a member's first turn can miss that bound, and the create then fails naming
the members.

The demo treats that as a failure and stops. It does not resume the create, even
though `create` is documented as resumable. A resumed create would show that
resume works rather than that a clean create works, and the resume path is itself
suspect. Destroy and create is the whole strategy here.

When a readback fails, read the member logs under `~/.cs-opencode-remote-logs`. A
first turn that dies with `TUI server does not know session` means a recorded
session outlived its campaign, which `make demo-reset` clears.

The archive has to happen while the members are alive. Their channels, configs and
transcripts live inside the sandboxes and go with them, and the audit runs in the
same pass. So `make demo` archives mid-cycle, and `make demo-destroy` only
destroys. It refuses when no archive exists, because a destroy without one loses
the evidence for good.

## Watching a campaign

A campaign reports its state through `cs-campaign observe`, but that command
gives you one snapshot per call. The script in `scripts/campaign-watch` turns it
into a continuous view, and it also reads two sources that `observe` does not
cover.

The first extra source is the orchestrator's log mirror, which records every
claim as it happens. The second is each member's agent-CLI log, which is where a
provider failure actually appears. This matters because a campaign that cannot
reach Fireworks still looks healthy to `observe`. The node is running and its
dispatch is open, so nothing in the derived state looks wrong.

```bash
make demo-watch                  # follow it until the run ends or breaks
./scripts/campaign-watch hello --once    # one report, then exit
```

The script prints one line per node on every look, and it follows that with any
new claims. It exits 0 when every dispatch has closed, which means the run
finished. Three conditions make it exit 1. The first is a node that reports `node-stuck`,
`node-stopped` or `node-unreachable`. The second is a provider error in a member
log. The third is an orchestrator that stops making claims for `WATCH_STALL`
seconds.

Other callers can use the script directly. Point `CS_CAMPAIGN_BIN` at the binary
you want, or let the script find `./tools/cs-campaign` or your `PATH`.

### Starting over completely

```bash
make demo-clean      # drops the members, removes .work, forgets the sessions
make clean-all       # removes tools and node_modules
```

Two things are left alone on purpose. Your credential at `~/.cs-keys/fireworks`
belongs to you rather than to this repository. The sandbox images in your container
store are shared with other work and are expensive to fetch again.

Note that `demo-clean` deletes evidence that cannot be rebuilt. A campaign's
channels and transcripts exist only while its members do, so an archive is the only
copy once they are gone. Use `make demo-destroy` instead when you want the members
gone but the archive kept, because that one refuses to run without an archive.

## A note on serving the app

The application runs inside the orchestrator, and the host reaches it through a
port forward. The member-side port stays fixed at 5173, because the role briefs
instruct the developer to use it. The host-side port is whichever one is free at
the time. Both the Tailscale address and the orchestrator's sandbox name are
queried when you run the target, so neither is written down anywhere.

## Committing to this repo

This repository is meant to be published, so its history is part of what readers see.
Keep commit subjects under 60 characters, and keep bodies to two paragraphs at most.

Never put an agent session link in a commit message. Such a link is private to whoever
ran the session, it is useless to everybody else, and it cannot be taken out once the
history is public. `make check` refuses one, so the rule holds without anybody
remembering it.

## What this repo commits

The committed files are the profile template, the mission, the three role briefs
and the ledger. Everything else is generated. The `tools` directory holds
binaries, `node_modules` contains packages, and `.work` collects the rendered
profile, the harvested application, the archive, the viewer page and the traces. All
three stay out of git, and all three rebuild from what is committed.

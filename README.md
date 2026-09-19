# tour

> **A hands-on tour of the codesweep tools for AI coding agents: six steps that need no key and
> spend nothing, ending with a three-agent campaign replayed from a recording, then the same
> campaign live.**

[![CI](https://github.com/codesweep-ai/tour/actions/workflows/ci.yml/badge.svg)](https://github.com/codesweep-ai/tour/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-Linux-lightgrey)

This repo is a tour of the codesweep tools. It starts with the smallest tool and ends
with the largest, so that you get a feel for each one before the next one builds on it.
Every tool is pinned, and every step prints the command it runs.

The first six steps need no key and they spend nothing. Step 6 runs three AI agents
that design, build, verify and serve a small web page, with every model call served
from a recording. Step 7 runs the same campaign live, and that one needs a Fireworks
key and a few cents.

Steps 1 to 4 run on any machine with node and Go. Steps 5 to 7 boot small virtual
machines, so they need Linux with podman and a writable `/dev/kvm`.

## Set up

You need node and npm, and a Go toolchain. Then run one command:

```bash
make setup
```

The tools come from two places. `cs-lint`, `cs-ledger` and the `opencode` agent
come from npm, pinned in `package.json`. The Go tools have no npm package and no tagged
release, so they come from the Go module proxy into a local `tools` directory. It takes
a couple of minutes, and it ends by saying what to run next.

Run `make` on its own at any time to see the tour again.

## How to read what a step prints

Each step runs its tool through a small script, `scripts/cs`. The script prints the
command, and then it runs exactly that command. A printed command looks like this:

```
  $ cs-ledger check ledger
```

That line is what you would type in a project of your own, where this Makefile does not
exist. The line and the run come from the same argument list, so they cannot disagree.

To type a command yourself, put the pinned tools on your `PATH` first:

```bash
eval "$(make env)"
cs-ledger check ledger
```

You need that step because a bare tool name finds whatever copy sits on your `PATH`.
That copy is often a different version from the one this repo pins. `make env` prints
the same three settings that `scripts/cs` applies, so both routes reach the same binary.

## The tour

### 1. cs-tracer: read what an agent did

Every AI coding CLI leaves its sessions on disk, in a format written for the tool rather
than for you. `cs-tracer` reads those files and writes one HTML page.

```bash
make try-tracer
```

It looks for your most recent Claude Code project, and then for your Codex sessions.
The command it runs is a single line:

```
  $ cs-tracer ~/.claude/projects/<your-project>/ --single -o .work/trace.html
```

Open the `file://` address it prints. You should see a timeline of the session, with
every tool call, the tokens and an estimate of the cost. The page is one file with no
server behind it. Set `TRACE_DIR` to draw a different directory.

Your sessions stay where they are, and the page goes into `.work`, which git ignores.
A machine with no sessions at all can run step 4 first, which leaves one behind.

### 2. cs-lint: a linter for documents

`cs-lint` checks how a repository's documents are written, and whether what they point
at still exists.

```bash
make try-lint
```

The step runs the linter three times. The first run reads this repository and passes.
The other two read a page with three planted faults, and they fail on purpose:

```
  $ cs-lint prose --root .work/lint-try

PROSE-103 error     49-word sentence (max 30) [README.md:6]
PROSE-104 error     2 em-dash(es); use a full stop, a comma, or cut the aside [README.md:6]

  $ cs-lint refs --root .work/lint-try --verbose

REF-101  error     docs/setup-guide.md is named here and does not exist [README.md]
REF-303  skip      no ledger/ledger.json at the root
```

Each line gives a rule number, what is wrong, and the file. `prose` checks how a page is
written, and `refs` checks that what it points at exists. A `skip` is a rule that had
nothing to read, and `--verbose` says why. The planted page is
`tour/broken-page.md.txt`, and the step tells you how to edit the copy until both pass.

`refs` caught a real mistake while this tour was written. This README quoted the id of
a practice record that the ledger does not hold, and rule `REF-303` refused it.

`cs-lint` has two more linters, and neither fits on one page. `cs-lint surface` compares
the documents with the program a repository builds. `cs-lint oss` checks that a
repository has what a published project needs.

### 3. cs-ledger: issue tracking that lives in the repo

A ledger is a directory of small JSON files, committed beside the code. Agents write the
records, and `cs-ledger` checks them and renders one HTML page for people to read.

```bash
make try-ledger
```

The step first checks the ledger in `ledger/`. Those records are real. They are
what went wrong while this demo was built, with the commit that fixed each one. Open
`ledger/ledger.html` to read them.

The step then copies the ledger into `.work` and works on the copy. A ledger has no
`add` command, because a record is a file you write. The step writes one from
`tour/new-record.json`, renders the page and checks it. Then it closes that record with
no evidence, and the check fails on purpose:

```
validation errors (3):
  - issues/<id>.json: status "closed" requires non-empty evidence.verified
  - issues/<id>.json: status "closed" requires evidence.commits, or links to the closing issues (delegation closure)
  - ledger.html: STALE — records changed without re-render. Run: cs-ledger render
check FAILED: 3 error(s), 0 warning(s)
```

Your output names the new record where this shows `<id>`. The first two errors say that
a closed record has to cite the commit that fixed it, and say how the fix was proved.
`cs-ledger check` looks that commit up in the repository, so a made-up one fails. The
third error is a separate gate. The page is rendered from the records, so a record that
changed without a render leaves a page that no longer matches. The step prints the
exact `evidence` line to write, and the two commands that make the check pass.
Run `scripts/cs cs-ledger guide` for the practice an agent follows day to day.

### 4. cs-vcr: replay an agent run for nothing

`cs-vcr` is a proxy that sits between an agent and its model provider. It records a
session into a cassette, which is a directory of text files. Later it replays that
cassette, and the whole agent loop runs again without calling the provider.

```bash
make try-vcr
```

The cassette in `cassettes/hello` holds one small session. An agent was asked to create
a file holding the word hello, which took three model calls. The step shows those three
steps and then replays them:

```
  $ cs-vcr cassette ls hello
  $ cs-vcr replay --cassettes cassettes --listen 127.0.0.1:<port> ...
  $ opencode run --model fireworks-ai/... 'Create a file called hello.txt ...'
```

The agent is the real `opencode`, and it writes the real file. Its key is the string
`not-a-real-key`. Look for `upstream calls 0` in the summary, which means no provider
was called. This is what lets a CI job test an agent with no credential and no cost.

The agent's command line does not say where its model calls go. Its environment does,
so the step prints those settings too. The one that matters most is a base URL ending
in `/c/fireworks/hello/v1`. That path tells `cs-vcr` which provider the call is for and
which cassette it belongs to. `scripts/cs cs-vcr config opencode --cassette hello
--provider fireworks` prints the settings for any agent. For `opencode` on Fireworks,
change the provider key it prints to `fireworks-ai`, which is the name `opencode` uses.

To drive the two halves yourself, start the proxy in one terminal and the agent in
another:

```bash
eval "$(make env)"
cs-vcr replay --cassettes cassettes --listen 127.0.0.1:18080    # terminal one
scripts/vcr-agent agent 18080                                   # terminal two
```

Stop `cs-vcr` with Ctrl-C, and it prints the same summary.

The proxy log in `.work/vcr/vcr.log` may say `served out of recorded order`. That is
expected here. `opencode` asks for a session title while it asks its first real question,
so the two requests can arrive in either order. `cs-vcr` allows for that by matching a
request against the next few recorded steps. It also says `tunnel refused` for `models.opencode.ai`,
which is the agent trying to reach a host of its own and being stopped.

A cassette only replays when the agent asks the same question it asked before. The
script `scripts/vcr-agent` holds still everything that could change the question. The
agent gets an empty home directory, a working directory inside this repo, and the
`opencode` version pinned in `package.json`. `make vcr-record` records the cassette
again, which calls Fireworks and costs a fraction of a cent.

### 5. cs-sandbox: a disposable machine for an agent

`cs-sandbox` creates an isolated Linux machine with the agent CLIs already installed.
This step needs podman and a writable `/dev/kvm`, and `scripts/cs cs-sandbox doctor`
says whether this machine has them. The first create on a machine pulls an image of
several gigabytes. After that a create takes about five seconds.

```bash
make try-sandbox
```

The step follows the whole loop, which is create, work, fetch and destroy:

```
  $ cs-sandbox create tour1234 --group tour1234 --repo .work/sandbox-try/repo:work --lend-api-key fireworks
  $ cs-sandbox exec tour1234.tour1234 -- bash -lc '...'
  $ cs-sandbox fetch tour1234.tour1234
  $ cs-sandbox destroy tour1234.tour1234 --force
```

The four digits come from the path of your clone, so two clones never collide. A sandbox
is addressed as its name, a dot, and its group.

The sandbox shares one repository with this machine and nothing else. A commit made
inside comes back with `fetch`. When you have a key at `~/.cs-keys/fireworks`, the step
also shows how lending works. Inside the sandbox the variable holds a loan token such
as `loan_tour1234_...`. The step searches `~`, `/etc` and `/run` inside the sandbox for
the real key and finds it in no file. It then calls the provider directly from inside,
and that call is refused with a 403. A model call has to go through the lender on this
machine, which is where the loan token is exchanged for the real key.

### 6. cs-campaign, replayed: the whole campaign for nothing

`cs-campaign` runs a fleet of agents, each in a sandbox of its own, against one mission.
This step runs a real campaign with no key, because `cs-vcr` from step 4 serves every
model call from a recording. It needs podman and KVM as step 5 does, and it takes about
five minutes.

```bash
make demo-replay
```

Three machines boot. An orchestrator designs a small web page and commits the design, a
developer builds it with the `@codesweep-ai/ui` design system, and a qa role checks it in
a real browser. Then the step fetches the work, archives the run, and builds the dispatch
page and the trajectories. It ends with the page served on a URL, and
`make show-reports` serves the two reports.

The agents' decisions are a recording, and everything they run is real. The installs,
the build, the browser check and the server all happen on your machine, so the page you
open was built here a minute ago. The proxy's own count ends the run, and it has to read
`upstream calls 0` and `misses 0`:

```
    requests                          157
    replayed                          157
    upstream calls                    0
    misses                            0
```

The step is `scripts/campaign-vcr`, and it uses three documented surfaces of the tools.
The profile's `env:` block gives each member `OPENCODE_BASE_URL`, which aims it at the
proxy. `cs-vcr` runs as one container on the campaign's own podman network, under the
alias `vcr`. `CS_SANDBOX_AGENT_HOME` moves where the credential lender reads a key, so
the key it lends is a file holding the words `not-a-real-key`.

A replay gives the same result every time, and that is deliberate. The cassette pins
what the models said. `NPM_CONFIG_BEFORE` makes npm resolve every package as it stood on
the recording date. Every commit carries one fixed author and date, so the commit ids in
the delivered repository are the same on every run and on every machine.

A replay reproduces the models' decisions, not the world's facts. If the network is
down and an install fails, a recorded agent still says what it said. So judge a replay
the way the step does: by the proxy's count, by the fetched commits, and by the page
answering.

### 7. cs-campaign, live: the same mission, decided afresh

This is the only step that spends. It runs the campaign from step 6 against the real
model, so the agents make their own decisions and the design comes out different each
time. It needs podman and KVM, and it needs a Fireworks key in two places. Export `FIREWORKS_API_KEY`, and write the same key to
`~/.cs-keys/fireworks` with mode `0600`. The campaign lends the key to its members, and
the lender reads a host file, so an environment variable alone is not enough.
`make setup` prints the three commands that write the file.

```bash
make demo-validate   # check the campaign, which costs nothing
make demo            # run it end to end, which takes about ten minutes
make demo-watch      # in a second terminal, follow progress and health
make show-reports    # read the dispatch page and the trajectories
make demo-destroy    # drop the members, and keep the archive
```

The campaign lives in `campaign/hello`. It holds a profile, a mission and three role
briefs, and `make demo-validate` checks all five files in a second. The orchestrator
owns the design of the page, and it commits that design as `DESIGN.md`. The developer builds it with
the `@codesweep-ai/ui` design system, and the qa role verifies it in a real browser.
The orchestrator checks both of them itself and serves the result.

Six commands do the work, and `make demo` prints each one as it runs:

| Command | What it does |
|---|---|
| `cs-campaign validate <profile>` | Checks the profile, the mission and the briefs. |
| `cs-campaign create hello --profile <profile>` | Boots the members and dispatches the mission. |
| `cs-campaign observe hello` | Reports the state of every member. |
| `cs-campaign fetch hello` | Brings the orchestrator's branch back to this machine. |
| `cs-campaign archive hello --output <dir>` | Collects every channel and transcript. |
| `cs-campaign destroy hello --force` | Removes the members. |

Two more tools turn the archive into pages. `cs-dispatch-viewer` writes the
campaign's timeline. `cs-tracer`, from step 1, writes a page for every member's sessions. The trajectory index
lists the members by name, because a session is titled by its dispatch and never by its
member.

Do not trust the outcome line on its own. Open a member's trajectory and read what it
did. Every defect recorded in `ledger/` was found that way.

## Using the tools in a project of your own

Every tool here is open source under the Apache-2.0 licence, and each one is a single
program that runs on your machine. None of them calls a hosted service. The only money
spent is what your own model provider charges, and only `cs-campaign` and a `cs-vcr`
recording ever call one.

The two npm tools install as dev dependencies, and the Go tools install with `go install`:

```bash
npm install --save-dev @codesweep-ai/lint @codesweep-ai/ledger
go install github.com/codesweep-ai/tracer/cmd/cs-tracer@latest
go install github.com/codesweep-ai/vcr/cmd/cs-vcr@latest
go install github.com/codesweep-ai/sandbox/cmd/cs-sandbox@latest
go install github.com/codesweep-ai/campaign/cmd/cs-campaign@latest
```

`cs-ledger init --project NAME --prefix ABC` starts a ledger in a repository, and
`cs-campaign init <name>` writes a first profile, mission and set of briefs. Each tool
carries its own manual, which `<tool> manual` prints.

The tools' own READMEs list Linux and macOS as platforms, and `cs-sandbox` adds Windows
under WSL2. `cs-sandbox` has two engines. The Firecracker engine needs Linux and KVM,
and it is the one this demo uses. The podman engine needs no KVM. This demo has only
been run on Linux with KVM, so the other routes are untested here.

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

## More about the campaign

### The stages

`make demo` runs seven stages in order, and each one also runs by itself. They are
`make demo-start`, `make demo-wait`, `make demo-fetch`, `make demo-archive`,
`make demo-dispatch-page`, `make demo-trajectories` and `make show-app`.

**`make demo-start`** boots three members and then runs the readback. A readback is a
first question to each member, which has to say back what its brief asks of it before
any work is dispatched. It prints one
line per member, and each one ends with `(confirmed by the answering turn)`. That
phrase matters: it means the model each member answered on is the model
the profile declared. This is where the run spends first.

**`make demo-fetch`** prints `tree differs from base (real changes present)` and a
commit count. It fails when the orchestrator branch matches its base, because that
means the campaign delivered nothing whatever it reported.

**`make demo-archive`** prints the list of `INCOMPLETE` markers, and that list should
be empty. Anything it could not collect leaves a marker rather than failing quietly.

**`make show-app`** and **`make show-reports`** print URLs on your Tailscale address.
`make show-reports` serves `.work/reports` and nothing else. The archive, the harvested
application and any page from step 1 stay off the network.

### Each member needs 4 GiB

The profile gives each member 4096 MiB. At 2048 the kernel killed the agent during
`npm install`, and nothing reported it. The member sat idle for five minutes until it
was prodded. When a member stalls, run `sudo dmesg | grep "Out of memory"` inside it
before you suspect the brief.

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

### Reports never carry over

`make demo-start` moves the previous run's archive and reports into `.work/runs`, under
the time of the move. `make show-reports` also refuses a page that is older than the
archive beside it.

The archive has to happen while the members are alive. Their channels, configs and
transcripts live inside the sandboxes and go with them, and the audit runs in the
same pass. So `make demo` archives mid-cycle, and `make demo-destroy` only
destroys. It refuses when no archive exists, because a destroy without one loses
the evidence for good.

### Watching a campaign

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
log. The third is an open dispatch with no activity at all for 1800 seconds, which
the `--stall` flag of the script changes.

### Serving the app

The application runs inside the orchestrator, and the host reaches it through a
port forward. The member-side port stays fixed at 5173, because the role briefs
instruct the developer to use it. The host-side port is whichever one is free at
the time. Both the Tailscale address and the orchestrator's sandbox name are
queried when you run the target, so neither is written down anywhere.

## Starting over

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

## Committing to this repo

Run `make check` before a commit. It runs the linters, checks the ledger, verifies the
cassettes, and refuses a local path or a session link.

This repository is meant to be published, so its history is part of what readers see.
Keep commit subjects under 60 characters, and keep bodies to two paragraphs at most.

Never put an agent session link in a commit message. Such a link is private to whoever
ran the session, it is useless to everybody else, and it cannot be taken out once the
history is public. `make check` refuses one, so the rule holds without anybody
remembering it.

## Recording the campaign again

The campaign's cassettes are bound to what the agents were asked. An edit to the
mission, a brief, the profile or `CAMPAIGN_VERSION` changes the prompts, and the
recording stops matching. `make check` compares a hash of those files with the one the
recording stored, and says when the cassettes are stale.

```bash
make demo-record     # calls Fireworks, for what a live run costs
make demo-replay     # then replay it, twice
```

A recording is kept only when it holds nothing of yours. A member carries the host's
username and a copy of the host's git identity, and an agent may print either one. The
proxy blanks those values, and every mail address, as it records. It puts this
machine's values back for whoever replays. The step then searches the recording for
your username, git name, git address, hostname and key, and runs the `cs-vcr` scrubber.
A recording that fails is moved into `.work` for you to read, where git ignores it.

Each recording holds different decisions, so replay a new one twice before you commit
it. `make check` also runs `make no-identity`, which searches every file git would
commit for those same values.

## What this repo commits

The committed files are the campaign, the ledger, four cassettes, the two files the tour
plants, and the scripts. Everything else is generated. The `tools` directory holds
binaries, `node_modules` contains packages, and `.work` collects whatever a step writes.
All three stay out of git, and all three rebuild from what is committed.

## License

This repository is released under the [Apache 2.0 licence](LICENSE), and so is every tool it
shows. [CONTRIBUTING.md](CONTRIBUTING.md) says how to propose a change.

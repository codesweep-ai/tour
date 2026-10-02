# tour

> **This repository is a hands-on tour of the six codesweep tools, which are small programs
> for working with AI coding agents. Six steps need no key and spend nothing, and a seventh
> runs three agents live.**

[![CI](https://github.com/codesweep-ai/tour/actions/workflows/ci.yml/badge.svg)](https://github.com/codesweep-ai/tour/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-Linux-lightgrey)

The codesweep tools are six small command-line programs for people who work with AI
coding agents, such as Claude Code, Codex and OpenCode. An agent is a program that
writes code for you: it reads your files, runs commands and makes changes on its own.

There are five problems that come with working this way. The first is that an agent needs
somewhere safe to run, because it executes whatever it decides to. The second is that a
job too big for one agent needs several, and somebody has to coordinate them. The third is
that the record an agent leaves of its work is in a format that people cannot read. The
fourth is that its work costs money to repeat, because every run calls a paid model. The
fifth is that its output has to be checked, and the faults that remain have to be written
down, by something other than the agent. Each tool below addresses one of those problems.

| Tool | What it is for |
|---|---|
| `cs-sandbox` | Gives an agent a disposable Linux machine of its own, so it cannot touch your files or see your keys. |
| `cs-campaign` | Runs a team of agents on one job, each in its own sandbox, and keeps the evidence of what each one did. |
| `cs-tracer` | Turns the session files an agent leaves behind into one page that a person can read. |
| `cs-vcr` | Records what passes between an agent and its model, and plays it back later, so a run can be repeated for nothing. |
| `cs-ledger` | Keeps a project's open problems as small files beside the code, written by agents and read by people. |
| `cs-lint` | Checks that a project's documents are clearly written, and that what they say is still true. |

The tools are separate programs, and each one is useful alone. They are also built to
work together. A campaign runs its agents in sandboxes, the tracer reads what those
agents did, and the recorder lets the whole campaign run again without paying for it.

This repo is a tour of all six. It starts with the smallest tool and ends with the
largest, so that you get a feel for each one before the next one builds on it. Every
tool is pinned to a version, and every step prints the command it runs, so you can see
what you would type in a project of your own.

The tour has seven steps. The first six need no key and they spend nothing. Step 6 runs
three agents that design, build, check and serve a small web page, with the model's
answers played back from a recording. Step 7 runs the same job live, and that one needs
a key for the Fireworks model service and about a dollar.

## Set up

You need these, and [INSTALL.md](INSTALL.md) says how to install them:

- Go 1.27.1.
- Node 24.21.0, with npm.
- For steps 5 to 7, Linux with podman 5.0 or later and a writable `/dev/kvm`.

Then run one command:

```bash
make setup
```

The tools come from two places. `cs-lint`, `cs-ledger` and the `opencode` agent
come from npm, pinned in `package.json`. The Go tools have no npm package and no tagged
release, so they come from the Go module proxy into a local `tools` directory. The first
run on a machine takes a couple of minutes, and a later one takes seconds, because npm
and Go both keep what they fetched. It ends by saying what to run next.

Part of the way through, `cs-sandbox` prints a line that starts with `next: sign in once
on the host`. That advice is for people who lend a subscription login to a sandbox. This
tour lends a key file and never a login, so you can ignore the line.

Run `make` on its own at any time to see the tour again.

## How to read what a step prints

Each step runs its tool through a small script, `scripts/cs`. The script prints the
command, and then it runs exactly that command. A printed command looks like this:

```
  $ cs-ledger check ledger
```

That line is what you would type in a project of your own, where this Makefile does not
exist. The script builds the printed line and the command from the same argument list.
This means that the line you read is always the command that ran.

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

prose: 2 error(s), 0 warning(s), 0 skipped

  $ cs-lint refs --root .work/lint-try --verbose

REF-101  error     docs/setup-guide.md is named here and does not exist [README.md]
REF-202  skip      the build shells out to nothing it checks for
REF-301  skip      no MANUAL.md in the document set
REF-302  skip      no AGENTS.md at the root
REF-303  skip      no ledger/ledger.json at the root

refs: 1 error(s), 0 warning(s), 4 skipped
```

Each line gives a rule number, what is wrong, and the file. Under each `prose` error the
tool also prints the sentence at fault, which this page leaves out. `prose` checks how a page is
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

The step first checks the ledger in `ledger/`, which is this repository's own. Each
record there describes something that went wrong while this tour was built, and it cites
the commit that fixed it. You can read them by opening `ledger/ledger.html`.

The step then copies the ledger into `.work` and works on the copy. `cs-ledger` has no
`add` command. The reason is that a record is an ordinary file, which a person or an
agent writes directly. The step writes one from
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

The agent in this step is the real `opencode` program, and it really does create the
file. The model is the only part that is replaced, so the key the agent holds is the
string `not-a-real-key`. Look for `upstream calls 0` in the summary, which means that
no provider was called. This is what lets a CI job test an agent with no credential and no cost.

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
again, which calls Fireworks and costs about two cents.

### 5. cs-sandbox: a disposable machine for an agent

`cs-sandbox` creates an isolated Linux machine with the agent CLIs already installed.
This step needs [podman](INSTALL.md#3-podman), and a writable
[`/dev/kvm`](INSTALL.md#4-devkvm-for-firecracker) for the Firecracker virtual machine
it boots. `scripts/cs cs-sandbox doctor` says whether this machine has them. In its
output, `ok` is a check that passed and `NO` is one that failed. A line that starts with `??` is advice, for example about memory or
disk space, and nothing in this tour depends on it. `doctor` checks every sandbox on the
machine, including other people's, and it ends with a failure when any of them has a `NO`.
For this step you only need the lines about podman and KVM to say `ok`. Step 6 explains a
`NO` that you are likely to see on a shared machine. The first create on a machine pulls an image of
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
  $ cs-sandbox group rm tour1234
```

The four digits come from the path of your clone, so two clones never collide. A sandbox
is addressed as its name, a dot, and its group.

The last command is there because of `--group`. A group has a network and a gateway of
its own, and they keep running after the last sandbox in it is destroyed. The step uses a
group so that it cannot touch anything else on your machine. A sandbox created without
`--group` joins the shared `default` group, and a destroy is all it needs.

The sandbox shares one repository with this machine and nothing else. A commit made
inside comes back with `fetch`.

An agent in the sandbox still needs a key to call its model, and `cs-sandbox` lends one
rather than copying it in. That is what `--lend-api-key fireworks` asks for. The sandbox
gets a loan token, a stand-in that is worth nothing anywhere else. Every model call goes
through a lender that `cs-sandbox` runs on this machine, and the lender swaps the token
for your real key on the way out. The agent uses your key without ever seeing it.

When you have a key at `~/.cs-keys/fireworks`, the step shows this at work. Inside the
sandbox the variable holds a loan token such as `loan_tour1234_...`. The step searches
`~`, `/etc` and `/run` inside the sandbox for the real key and finds it in no file. It
then calls the provider directly from inside, and that call is refused with a 403,
because the sandbox reaches the provider only through the lender. Without a key file,
the step skips this part.

### 6. cs-campaign, replayed: the whole campaign for nothing

`cs-campaign` runs a fleet of agents, each in a sandbox of its own, against one mission.
This step runs a real campaign with no key, because `cs-vcr` from step 4 serves every
model call from a recording. It needs podman and KVM as step 5 does, and it takes about
seven minutes. Most of that is the agents' real work, such as `npm install` and the build.

```bash
make demo-replay
```

Three machines boot, and each agent first passes a readback. A readback is a first
question to an agent, which has to say back what its brief asks of it before any work is
handed out. The step prints one `ok  readback` line for each agent. Each line ends with
`(confirmed by the answering turn)`. That means the model the agent answered
on is the model that its profile declares.

An orchestrator then writes the design of a small web page and commits it. A developer
builds the page with the `@codesweep-ai/ui` design system, and a qa agent checks it in a
real browser. The step then fetches their work and archives the run.

The step ends by printing three addresses. The first is the web page the agents built,
which runs inside the orchestrator's machine. The other two are reports on how they
built it, written as files on this machine. The dispatch page is a timeline of the run,
where a dispatch is one piece of work that the orchestrator hands to another agent. The
trajectories record each agent's sessions, every tool call included, and you review them
on the trace pages that `cs-tracer` from step 1 draws. `make show-reports` serves the two
reports, so that another machine can open them.

In a replay, only the agents' decisions come from the recording. Every command that
they decide to run is executed for real. The installs, the build, the browser check and
the server all happen on your machine, so the page you open was built here a minute ago.
The run ends with the proxy's own count of what it served, and then the step says whether
the replay passed. On a machine where nothing else is going on, the count looks like this:

```
    requests                          157
    replayed                          157
    recorded                          0
    upstream calls                    0
    misses                            0
    rejected                          0
    drifted observations              962
    out of recorded order             5
```

Most of your counts will differ from these. Two of them decide whether the replay passed.
The first is `upstream calls`, which has to be 0, because it counts the calls that reached
a real provider. The second is `misses`. A miss is a request that the recording does not
hold, and the proxy rejects it, so `rejected` moves with it. A miss that an agent sent is
a fault, and on a quiet machine `misses` has to be 0.

There is one kind of miss that no agent sends, and you may well see it. `cs-sandbox
doctor` checks every lender on the machine, and it does that by asking each proxy for `/`.
If anybody runs it while your replay is going, the proxy counts one miss for each of your
agents that is up at that moment. That is three at most for each run of `doctor`, and two
when the last agent has not booted yet. The step recognises those misses, because a model call never asks for `/`. It
prints three more lines under the count, and the last of them is the one to read:

```
    misses                            3
    of those misses, 3 asked for `/` and not for a model. No agent sent them:
    they are `cs-sandbox doctor`, run somewhere on this machine, checking that the proxy answers.
    misses that an agent sent         0
```

In that case `requests` is larger than `replayed` by the same number, and the replay has
still passed. The step fails only when `misses that an agent sent` is more than 0. You do
not have to work any of this out, because the step ends with either `The replay passed`
or a line that starts with `FAILED`. The same `doctor` also prints `NO` lines that say
the proxy `does not answer`. The proxy did answer, with a 400, because `/` is not a model
call, so those lines are harmless too.

The other two counts are not faults. A drifted observation is a tool result that differs
from the recorded one, such as a timing, a port or a file time. A screenshot that an agent
takes of the page is treated the same way, because two renderings of one page differ by a
few bytes. `cs-vcr` matches exactly on what an agent asked the model, and loosely on what
its tools printed, so hundreds of drifted observations are normal. A request out of
recorded order is an agent asking for a session title beside its first real question.

The step is `scripts/campaign-vcr`, and it uses three documented surfaces of the tools.
The profile's `env:` block gives each member `OPENCODE_BASE_URL`, which aims it at the
proxy. `cs-vcr` runs as one container on the campaign's own podman network, under the
alias `vcr`. `CS_SANDBOX_AGENT_HOME` moves where the credential lender reads a key, so
the key it lends is a file holding the words `not-a-real-key`.

A replay is designed to give the same result every time, and three things make that
possible. The first is the cassette, which fixes what the models said. The second is
`NPM_CONFIG_BEFORE`, which makes npm resolve every package as it stood on the recording
date. The third is that every commit carries one fixed author and date. As a result, the
commit ids in the delivered repository are the same on every run and on every machine.

Time is the one input that a recording cannot hold. The orchestrator waits for the other
agents with a command that gives up after 240 seconds and asks to be called again. A live
orchestrator calls it again, and a recorded one does whatever it did when it was recorded.
So the step lets a wait last as long as the recorded model allowed that command, which is
840 seconds in this recording. If a wait still gives up where the recorded one had an
answer, the step fails and says that the machine was too slow.

The trajectories of a replayed run show a cost of about a dollar. That is what the
recording cost when it was made, because the recorded answers carry the provider's token
counts. The replay itself costs nothing.

A replay reproduces what the models decided, and it does not reproduce the state of the
world. For example, if the network is down and an install fails, a recorded agent still
replies as it did when the install succeeded. For that reason you should judge a replay
the way the step does. It looks at the proxy's count, at the fetched commits, and at
whether the page answers.

The three machines stay up when the step ends, because the page is served from one of
them. `make demo-destroy` removes them and keeps the archive. A step that fails leaves
them up too, and it says so. Running `make demo-replay` again removes them first.

### 7. cs-campaign, live: the same mission, decided afresh

This is the only step that spends, and a run costs about a dollar. It runs the campaign
from step 6 against the real model, so the agents make their own decisions and the
design comes out different each time. It needs podman and KVM, and a Fireworks key in
`~/.cs-keys/fireworks` with mode `0600`. The campaign lends that key to its members, as
step 5 showed. `make setup` prints the three commands that write the file.

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

Six commands do the work, and `make demo` prints each one as it runs. The campaign is
named `hello` with four digits from the path of your clone, such as `hello1234`.
`cs-campaign` keeps its records for each user and not for each clone, so the digits stop
two clones replacing each other's campaign. The table below writes it as `<name>`:

| Command | What it does |
|---|---|
| `cs-campaign validate <profile>` | Checks the profile, the mission and the briefs. |
| `cs-campaign create <name> --profile <profile>` | Boots the members and dispatches the mission. |
| `cs-campaign observe <name>` | Reports the state of every member. |
| `cs-campaign fetch <name>` | Brings the orchestrator's branch back to this machine. |
| `cs-campaign archive <name> --output <dir>` | Collects every channel and transcript. |
| `cs-campaign destroy <name> --force` | Removes the members. |

Two more tools turn the archive into pages. `cs-dispatch-viewer` writes the
campaign's timeline. `cs-tracer`, from step 1, writes a page for every member's sessions. The trajectory index
lists the members by name, because a session is titled by its dispatch and never by its
member.

You should not rely on the outcome line alone, because an agent can report success for
work that is wrong. It is better to open a member's trajectory and read what it did.
Every defect recorded in `ledger/` was found that way.

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

Of those versions, `cs-sandbox` is the only one that has to agree with campaign at
runtime. The reason is that campaign executes `cs-sandbox` on every run. `make doctor`
fails when the two disagree. The sandbox image carries its own copy of `cs-vcr` inside it. Campaign
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
phrase is important, because it means that the model each member answered on is the
model the profile declared. The readback is also the first point at which a live run
spends money.

**`make demo-fetch`** prints `tree differs from base (real changes present)` and a
commit count. It fails when the orchestrator branch matches its base, because that
means the campaign delivered nothing whatever it reported.

**`make demo-archive`** prints the list of `INCOMPLETE` markers, and that list should
be empty. Anything it could not collect leaves a marker rather than failing quietly.

**`make show-app`** and **`make show-reports`** print URLs. They are on your Tailscale
address when Tailscale is up, so that another machine of yours can open them. They are
on `127.0.0.1` when it is not, and the step says so. Set `BIND_ADDR` to choose an address
yourself. None of these servers binds to every interface.
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
though `create` is documented as resumable. There are two reasons. The demo exists to
show that a clean create works, and a resumed create would not show that. The resume
path is also not yet trusted, so the demo does not rely on it. For that reason the demo always destroys a failed campaign and creates a new
one.

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
./scripts/campaign-watch <name> --once   # one report, then exit
```

`cs-campaign` calls each member's machine a node, so the two words mean the same thing
here. The script prints one line per node on every look, and it follows that with any
new claims. It exits 0 when every dispatch has closed, which means the run
finished. Three conditions make it exit 1. The first is a node that reports `node-stuck`,
`node-stopped` or `node-unreachable`. The second is a provider error in a member
log. The third is an open dispatch with no activity at all for 1800 seconds, which
the `--stall` flag of the script changes.

### Serving the app

The application runs inside the orchestrator, and the host reaches it through a
port forward. The member-side port stays fixed at 5173, because the role briefs
instruct the developer to use it. The host-side port is whichever one is free at
the time. Both the address to serve on and the orchestrator's sandbox name are
queried when you run the target, so neither is written down anywhere.

## Starting over

```bash
make demo-clean      # drops the members, removes .work, forgets the sessions
make clean-all       # removes tools and node_modules
```

Both targets deliberately leave two things alone. The first is your credential at
`~/.cs-keys/fireworks`, which belongs to you rather than to this repository. The second
is the set of sandbox images in your container store. Those images are shared with other
work, and they are expensive to fetch again.

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
make demo-record     # calls Fireworks, for about a dollar
make demo-replay     # then replay it, twice
```

A recording is kept only when it holds nothing of yours. A member carries the host's
username and a copy of the host's git identity, and an agent may print either one. The
proxy blanks those values, and every mail address, as it records. It puts this
machine's values back for whoever replays. The step then searches the recording for
your username, git name, git address, hostname and key, and runs the `cs-vcr` scrubber.
A recording that fails is moved into `.work` for you to read, where git ignores it.

Each recording holds different decisions, so replay a new one twice before you commit
it. `make check` cannot do that for you. It proves that a cassette is whole and that the
campaign has not changed since the recording. It does not run the agents, so it cannot
show that they still ask the questions that were recorded. `make check` also runs `make no-identity`, which searches every file git would
commit for those same values.

## What this repo commits

The committed files are the campaign, the ledger, four cassettes, the two files the tour
plants, and the scripts. Everything else is generated. The `tools` directory holds
binaries, `node_modules` contains packages, and `.work` collects whatever a step writes.
All three stay out of git, and all three rebuild from what is committed.

## License

This repository is released under the [Apache 2.0 licence](LICENSE), and so is every tool it
shows. [CONTRIBUTING.md](CONTRIBUTING.md) says how to propose a change.

# Contributing to tour

These rules apply to **humans and coding agents alike**. If you are an agent working in this repo,
read this file before you change anything and follow it.

This repository is a demonstration, so it ships no program of its own. Its product is the tour in
[README.md](README.md), and a change is good when a stranger can still follow that tour.

Bug reports and pull requests are welcome. For a security issue, use GitHub's private
vulnerability reporting on this repository's Security tab, rather than opening a public issue.

## Submitting a change

File a bug or an idea as a GitHub issue on this repository. A defect in one of the tools belongs in
that tool's own repository, which the README names. For a fix that stands on its own, a pull
request on its own is enough. For anything that changes behaviour a user can see, open an issue
first, so the design gets settled before you write it.

1. Fork the repository, and create a branch off `main`.
2. Make the change, with its test.
3. Run `make ci`, which is every gate CI runs.
4. Open a pull request against `main`, and say what the change does and why.

Expect comments rather than silence, and expect a small change to move quickly. A reviewer asks
whether the change keeps the design rules below, whether a test fails without it, and where a reader
would find it documented.

By opening a pull request you agree that your contribution ships under the
[Apache 2.0 licence](LICENSE) this project is released under.

## Before you push

One command:

```bash
make ci
```

That is every gate the CI workflow has, on this machine and in the order the workflow takes them,
so a green run here is a green run there. `make check` is the faster subset to keep beside you
while you work, and `make ci` is the one that has to pass.

No linter needs installing. Every one the gates shell out to is pinned, and `make ci` fetches it:
`cs-lint` and `cs-ledger` in `package.json`, and `actionlint` in the `Makefile`.

Moving a linter pin is an edit to `package.json`, or to `ACTIONLINT_VERSION` in the `Makefile` for
`actionlint`. A linter release reaches you when you ask for it, not on an unrelated pull request.

`make try-sandbox` and `make demo` boot virtual machines, so CI cannot run them. Run them yourself
when you change a script they use, or a file under `campaign/`. `make demo` spends about a dollar.

This repository keeps a **ledger** of open issues in `ledger/`. Read
[`ledger/AGENTS.md`](ledger/AGENTS.md) before you start work, and follow it as you go. A commit
that touches `ledger/` needs `cs-ledger render && cs-ledger check` to pass first, and
`make ledger` runs the check half.

## Design rules

1. **Every tool runs through `scripts/cs`.** The script prints the command and then runs that same
   argument list, which is what keeps the tour honest. A recipe that calls a tool directly hides it
   from the reader, and may run a copy that is not the pinned one.
2. **Judge a campaign from the trajectories, not from its outcome line.** Every defect in the
   ledger was found by reading what a member did. After a change to a brief, run the campaign and
   read each member's session before you call the change good.
3. **Record the campaign again after you change what its agents are asked.** The mission, a
   brief, the profile and `CAMPAIGN_VERSION` all reach the prompts. `make check` says when the
   campaign's cassettes are stale, and `make demo-record` records them again for about a dollar.
   Replay a new recording twice before you commit it, because each one holds different decisions.
4. **Record the small cassette again after you move the `opencode` pin.** Another version of the
   agent sends another prompt, and the old cassette stops matching. `make vcr-record` does it, and
   it scrubs the result for keys. It calls Fireworks, and it costs about two cents.

## Tests

Ship a test with your change. Where a behaviour genuinely cannot be observed in a test, say so in
the pull request.

`make test` runs the three tour steps that boot no machine: `make try-lint`, `make try-ledger` and
`make try-vcr`. Each one is its own test, and fails when its tool stops behaving as the tour says.
None needs a key, and none spends.

## Commits

**Keep it short.** One idea per commit, and a message a reader takes in at a glance. If a change
will not fit one idea, split it.

**Subject**, always. Under 60 characters, imperative, no trailing period, completing *"If applied,
this commit will …"*. Say what the change does in plain English. The test: would this subject make
sense to someone who has not read the diff and does not know this codebase? Use no category label:
`fix(proxy):`, `bugfix:` and `[docs]` each name a class of change rather than the change itself,
which the diff already shows. The gate fails on one, so amend before you push.

**Body**, rarely. Most commits need none. Add one only when the subject leaves a question a reader
would otherwise have to open the diff to answer, and then answer that question. A sentence or two
does it. Wrap it at 72 columns.

Leave out how the work was scheduled, how you tested it, and what led you to it, and stop once the
question is answered. A second paragraph usually means the message has turned into a report of the
session. A rule's reason belongs beside the rule, and the investigation that found it belongs in
the pull request.

```
Serve on 127.0.0.1 when Tailscale is not up
```

```
Let a replayed wait last as long as the recording allows

A recorded orchestrator does not call a wait again, so one that
gives up early on a slow machine accepts work that is not there.
```

Keep the `Co-Authored-By:` trailer when an agent wrote the change. Drop any trailer linking to the
agent's session or transcript. Such a link is private to whoever ran it and dead to everyone else,
and it cannot be fixed after publication. `make check` refuses one.

## Docs

Behaviour a user can see belongs in the docs, updated in the same commit as the code. Each document
has one job, so a fact lives in exactly one of them and the others link to it.

| If you are writing | It goes in |
|---|---|
| What the tools are for, and each step of the tour | `README.md` |
| What the machine needs before `make setup`, and how to install it | `INSTALL.md` |
| How to work on the tour itself | `CONTRIBUTING.md` |
| Where an agent working in this repository looks first | `AGENTS.md` |

The README quotes what each step prints. Quote a tool's output as the tool prints it, and run the
step again after you edit the quote.

## Writing

Six principles do most of the work. Read them before you write a document, and apply them when you
edit one:

1. **Introduce a term where you first use it**, in the same sentence, or link to the page that
   defines it. A reader should never meet a word the docs have not explained.
2. **State the point first, then qualify it.** Opening with the qualifier makes the reader decode
   the sentence backwards.
3. **Give every sentence a subject and a verb.** "Two version numbers, one verdict, one remedy"
   reads as knowing rather than clear. Say what the thing is.
4. **A how-to is steps that work.** Put the reasons somewhere else. A reader working through
   one wants commands that run.
5. **Describe what the software does, not how it came to do it.** Leave out what the project used
   to do, what was tried and dropped, and numbers from a run somebody did once.
6. **Do not explain a design by contrast with a worse one.** Say what it is and what you get,
   rather than asking the reader to picture a design nobody proposed.

The mechanical rules are enforced rather than restated here.
[`cs-lint`](https://github.com/codesweep-ai/lint) carries them, and `make check` runs it over this
repository. To read what a rule wants and the guidance behind it:

```bash
scripts/cs cs-lint prose --explain
```

That listing is the authority. Where this section and the linter disagree, the linter is right.
Turning a check off is a waiver: write it under `allow` in [`.cs-lint.yaml`](.cs-lint.yaml) with the
reason, which is printed with the finding.

## AI-assisted contributions

An agent wrote most of this repository, and you are welcome to use one. The standard is the same
either way: you are responsible for what you submit.

Point your tool at [`AGENTS.md`](AGENTS.md), which routes it to the documents that hold the
conventions, and check three things before you open the pull request:

- You understand every line, and can answer a question about it without going back to the tool.
- You ran `make ci` and it passed.
- You cut what the tool added to fill space. A model pads a commit body to the shape it was shown,
  and comments that restate the code around them. Both read as noise to a maintainer, and both are
  yours to remove.

Keep the `Co-Authored-By:` trailer, which is how the work is disclosed. An unattended agent must not
open pull requests or comment on this repository.

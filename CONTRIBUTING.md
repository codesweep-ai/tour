# Contributing to simple-tools-demo

These rules apply to **humans and coding agents alike**. If you are an agent working in this repo,
read this file before you change anything and follow it.

This repository is a demonstration, so it ships no program of its own. Its product is the tour in
[README.md](README.md), and a change is good when a stranger can still follow that tour.

Bug reports and pull requests are welcome. File a bug or an idea about the tour as a GitHub issue
on this repository. A defect in one of the tools belongs in that tool's own repository, which the
README names. For a security issue, use GitHub's private vulnerability reporting on the Security
tab, rather than opening a public issue.

## Submitting a change

1. Fork the repository, and create a branch off `main`.
2. Make the change.
3. Run `make ci`, which is every gate CI runs.
4. Open a pull request against `main`, and say what the change does and why.

By opening a pull request you agree that your contribution ships under the
[Apache 2.0 licence](LICENSE) this project is released under.

## Before you push

One command:

```sh
make ci
```

It runs `make check` and then `make test`. `make check` runs the three linters that need no build,
checks the ledger, verifies the cassette, and refuses a local path or a session link. `make test`
runs the three tour steps that check themselves and need no machine to boot. They are
`make try-lint`, `make try-ledger` and `make try-vcr`. None of them needs a key, and none spends.

`make try-sandbox` and `make demo` boot virtual machines, so CI cannot run them. Run them yourself
when you change a script they use, or a file under `campaign/`. `make demo` spends a few cents.

## The rules a diff does not show

1. **Every tool runs through `scripts/cs`.** The script prints the command and then runs that same
   argument list, which is what keeps the tour honest. A recipe that calls a tool directly hides it
   from the reader, and may run a copy that is not the pinned one.
2. **Judge a campaign from the trajectories, not from its outcome line.** Every defect in the
   ledger was found by reading what a member did. After a change to a brief, run the campaign and
   read each member's session before you call the change good.
3. **Record a cassette again after you move the `opencode` pin.** Another version of the agent
   sends another prompt, and the old cassette stops matching. `make vcr-record` does it, and it
   scrubs the result for keys. It calls Fireworks, and it costs a fraction of a cent.

## Issues

This repository keeps a **ledger** of open issues in `ledger/`. Read
[`ledger/AGENTS.md`](ledger/AGENTS.md) before you start work, and follow it as you go. A commit
that touches `ledger/` needs `make ledger-render` to pass first. Land the fix before you close its
record, because a closed record cites the commit that fixed it.

## Commits

**Keep it short.** One idea per commit, and a message a reader takes in at a glance.

**Subject**, always. Keep it under 60 characters, in the imperative, with no trailing period. Say
what the change does in plain English, with no category label such as `fix:` or `[docs]`.

**Body**, rarely. Add one only when the subject leaves a question a reader would otherwise have to
open the diff to answer, and then answer that question. Keep it under 120 words. A second paragraph
usually means the message has turned into a report of the session.

Keep the `Co-Authored-By:` trailer when an agent wrote the change. Drop any trailer linking to the
agent's session or transcript. Such a link is private to whoever ran it and dead to everyone else,
and it cannot be fixed after publication. `make check` refuses one.

## Writing

The README is the product here, so it is held to the same rules as the tools' own documents.

1. **Introduce a term where you first use it**, in the same sentence.
2. **State the point first, then qualify it.**
3. **Give every sentence a subject and a verb.**
4. **A how-to is steps that work.** Quote a tool's output as the tool prints it, and run the step
   again after you edit the quote.
5. **Describe what the software does, not how it came to do it.**

The mechanical rules are enforced rather than restated here.
[`cs-lint`](https://github.com/codesweep-ai/lint) carries them, and `make check` runs it over this
repository. `scripts/cs cs-lint prose --explain` prints what each rule wants. Turning a check off
is a waiver: write it under `allow` in [`.cs-lint.yaml`](.cs-lint.yaml) with the reason.

## AI-assisted contributions

An agent wrote most of this repository, and you are welcome to use one. The standard is the same
either way: you are responsible for what you submit.

Point your tool at [`AGENTS.md`](AGENTS.md), and check three things before you open the pull
request:

- You understand every line, and can answer a question about it without going back to the tool.
- You ran `make ci` and it passed.
- You cut what the tool added to fill space.

Keep the `Co-Authored-By:` trailer, which is how the work is disclosed. An unattended agent must not
open pull requests or comment on this repository.

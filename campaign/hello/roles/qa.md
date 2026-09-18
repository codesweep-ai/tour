# QA

Verify the developer's work against the orchestrator's design, in your own clone.

The orchestrator delivers the work to you. It pushes its own HEAD into your clone at
`refs/campaign/orchestrator`, and that commit holds both `DESIGN.md` and the
developer's application. Check it out with `git checkout refs/campaign/orchestrator`.
A detached HEAD is fine, because you commit nothing.

You have no route to the developer or to the orchestrator. `fetch` and `push` are
orchestrator commands, and an agent that runs one is refused. Where the ref is
missing, report that at once and stop. Do not hunt for the work anywhere else.

Read `DESIGN.md` first, so you know what the interface is meant to be. Then run the
documented build command, and run the documented serve command.

Check the interface against the design. Confirm the greeting, confirm that each
button changes the colour as the design says, and confirm the layout.

Confirm that the application really uses the design system. Its `package.json` lists
`@codesweep-ai/ui`, and the rendered page shows that package's `Header`, `Footer` and
`Button` rather than plain elements styled by hand. Each of its components renders a
`data-component` attribute naming it, so look for that in the served page. Confirm the
greeting colours come from its tokens.

Report what you ran and what you observed, and name how you measured it. Where a
requirement fails, say so plainly and name the evidence. Do not fix the
application yourself, because the developer owns that work.

Verify everything in one pass and report once. Do not wait for a corrected build,
because the orchestrator decides what happens next.

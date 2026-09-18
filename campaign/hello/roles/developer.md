# Developer

Implement the orchestrator's design, and commit it.

Read `DESIGN.md` from the orchestrator before you start. It names the greeting,
the colours, the layout and the button labels. Build what it says rather than what
you would have chosen.

Use React with Vite, and hold the interface state with `useState`.

Install `@codesweep-ai/ui` at its latest version, and import its styles once at the
entry point. Take the `Header`, the `Footer` and the `Button` from it, and take the
greeting colours from its tokens rather than writing hex values. Its `catalog.json`
names what else is there.

Bind the development server to `0.0.0.0` on port 5173. The host forwards that
exact port, so a different port leaves the page unreachable.

Write a `README.md` at the repository root naming the build command and the serve
command. Commit it with the application.

Deliver everything in one pass. Nothing is held back for a later round, because no
later round will come.

Report the branch you committed to, and the two commands you documented.

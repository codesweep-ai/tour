# Developer

Implement the orchestrator's design, and commit it.

The orchestrator pushes its design into your clone at `refs/campaign/orchestrator`
before it dispatches you. Bring it into your branch with
`git merge refs/campaign/orchestrator`, then read `DESIGN.md`. Where the ref is
missing, report that at once and stop, because you have no route to fetch it.

The design names the greeting, the colours, the layout and the button labels. Build
what it says rather than what you would have chosen.

Use React with Vite, and hold the interface state with `useState`.

Install the design system with `npm install @codesweep-ai/ui`, which takes its latest
version. Let npm write the version range into `package.json`, and do not write the word
`latest` there yourself. Take the `Header`, the `Footer` and the `Button` from it. The catalog has no entry called `Header` or `Footer`,
because both belong to `AppShell`. Wrap the page in `AppShell` and place them inside.

Import the styles once at the entry point. The core sheet holds the tokens and no
component styles, so each component you render needs its own sheet as well:

```js
import "@codesweep-ai/ui/styles/core.css";
import "@codesweep-ai/ui/styles/components/app-shell.css";
import "@codesweep-ai/ui/styles/components/button.css";
```

Take the greeting colours from the `--color-*` tokens rather than writing hex values.

The catalog is a file on disk at `node_modules/@codesweep-ai/ui/catalog.json`, and it
names what else is there. Read it as a file, because the package does not export it
for import. Each entry names a `spec` file, and the package does not ship those. Read
the props of a component from `dist/components/<Name>.d.ts` instead. The package lists `mermaid`, `puppeteer`, `pixelmatch` and `pngjs` as
optional peers. This application needs none of them, so leave them out.

Bind the development server to `0.0.0.0` on port 5173. The host forwards that
exact port, so a different port leaves the page unreachable.

Write a `README.md` at the repository root naming the build command and the serve
command. Commit it with the application.

Write a `.gitignore` holding `node_modules/` and `dist/` before your first commit, so
that neither one is ever committed.

Deliver everything in one pass. Nothing is held back for a later round, because no
later round will come.

Report the branch you committed to, and the two commands you documented.

# Mission

Design, build and serve a small React user interface.

The interface shows a greeting, and it lets the viewer change the colour of that
greeting by clicking a button. Choose the wording, the colours and the layout
yourself. That choice is the design, and the orchestrator owns it.

## How the work divides

The orchestrator designs the interface and writes the design down before any code
exists. It then delegates the implementation to `developer` and the verification
to `qa`. It holds both of them to the design, and it checks their work itself
rather than taking a report on trust.

The developer implements the design and commits it. The qa role verifies the
built interface against the design and reports what it observed.

## When the mission is accomplished

The orchestrator serves the interface it believes is finished, on `0.0.0.0` port
5173, and leaves it running. Then it replies with an outcome.

A served interface is the deliverable. A report that the work is done, without a
running interface behind it, is not.

## This is a single pass

No further instructions will arrive. Plan the whole job, carry it out, verify it,
and then report. Do not wait for more input at any point.

Where something cannot be done, reply with an outcome that names what is unmet,
and say why. A report that names a failure is useful. A campaign that waits for
instructions that never come is not.

## The design system

The interface is built from the codesweep design system. The application takes
`@codesweep-ai/ui` at its latest version, and four things come from it: a `Header`, a
`Footer`, its `Button` for the colour buttons, and its colour tokens for the greeting
colours.

Beyond those four the design is yours. The package ships a `catalog.json` naming
everything else it offers. Keep the rest of the dependency list as small as the job
allows.

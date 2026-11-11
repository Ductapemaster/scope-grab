# CLAUDE.md — how to work in this repo

A native macOS (SwiftUI) app that captures the Rigol DS2072A's screen over USB (USBTMC) to the clipboard and a PNG. Overview + current state: see README.md and `docs/`.

## Conventions
- Swift package, no Xcode project. `swift test` for unit tests; `SCOPE_USB=1 swift test` adds live tests against the scope on USB.
- `./build.sh` builds `build/Scope Grab.app`; `./build.sh install` copies it to `~/Applications`.
- Protocol and file logic go in `ScopeGrabCore` (testable); `ScopeGrab` holds only UI.
- Settings live in UserDefaults under `com.dankouba.scopegrab` (`folder`, `filenameTemplate`).

## Guardrails
- SCPI commands that change scope state (`:STOP`, `:RUN`, settings) affect Dan's bench session; restore the prior state.

## Where things go
Create each doc straight into its home by what it is — the folder *is* its role, and it exists as soon as its first file does (don't pre-create `docs/`; a fresh repo is just this file + README.md):
- **CLAUDE.md** (this) — how to work here. Put a directive in the narrowest-scope CLAUDE.md that covers the work: this root file for repo-wide rules, a **`<component>/CLAUDE.md`** for one subsystem (create it if missing), not a README.
- **README.md** — what this is, how to run it, the directory map.
- **docs/README.md** — the durable overview: the model + the *why*; the docs landing page. Present tense — no dates, "done", or history (git holds how it got here).
- **docs/ROADMAP.md** — the single prioritized "what's next."
- **docs/status.md** — the resume pointer: `## Status — resume here` only, overwritten each checkpoint (never a dated ledger). Synthesis belongs in docs/README.md.
- **docs/design/`<x>`.md** — as-built design depth for a subsystem (design tied to one component's code lives with it, e.g. `<component>/ARCHITECTURE.md`).
- **docs/research/`<x>`.md** — an open investigation / unknown.
- **docs/archive/`<effort>`/** — a shipped effort's frozen design + plan + review, with a README breadcrumb.

A doc only *moves* when its state changes, riding an event you're already doing: a plan freezes into `docs/archive/<effort>/` when it ships, and its durable lessons fold up into `docs/README.md` then. Never annotate in place; relocate.

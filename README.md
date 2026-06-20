# triple-crown

One-command setup for the Triple Crown AI dev workflow — **GSD (gsd-core) + gstack + superpowers + the `/start` command** — on Claude Code and Codex. Works on a Claude-only, Codex-only, or both machine.

## Install (macOS / Linux / WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/kwanGDss/triple-crown/main/install.sh | bash
```

> **Windows:** run this **inside WSL** (Ubuntu). Native Windows shell is not supported.

The installer is self-contained — the `/start` skill and the PC-wide guidelines are embedded, no extra downloads.

On launch it **asks which runtime(s) to set up** — pick **Claude Code**, **Codex**, or **both**:

```
Which runtime(s) to set up?  (you can pick BOTH)
   1) Claude Code   [detected]
   2) Codex         [detected]
   3) Both
Enter 1, 2, 3 (or e.g. '1 2')  [Enter = all detected]:
```

The prompt works even through `curl … | bash` (it reads your terminal). For **non-interactive / CI**, choose with flags or an env var instead:

```bash
curl -fsSL https://raw.githubusercontent.com/kwanGDss/triple-crown/main/install.sh | bash -s -- --claude   # or --codex, or --all
TC_RUNTIMES="claude codex" bash <(curl -fsSL https://raw.githubusercontent.com/kwanGDss/triple-crown/main/install.sh)
```

### Prerequisites (install inside the same environment first)
- **At least one runtime** — **Claude Code** CLI and/or **Codex** CLI (each one you use must be **logged in**)
- **Node.js 18+** (`node`/`npx`)
- **git**

It sets up only the runtime(s) you choose (a selected runtime whose CLI isn't installed is skipped with a warning):

| | installs |
|---|---|
| **Claude Code** | gstack, superpowers, GSD, `/start`, PC-wide guidelines (auto-bootstraps **bun** for gstack) |
| **Codex** | GSD, `/start`, PC-wide guidelines |

On WSL, GSD hooks use `--portable-hooks`. gstack & superpowers are Claude-only by design.

## Use

Restart Claude Code (or Codex), then:

```
/start "<your idea>"      # Claude Code
$start  "<your idea>"      # Codex
```

Runs the current Triple Crown lifecycle: **validate → scaffold → build → test** (stops before shipping).
`--bootstrap` stops after design · `--fast` skips strategy validation.

## What each tool does
- **GSD** — spine: spec → discuss → plan → execute → verify (cross-runtime, file-persistent)
- **gstack** *(Claude only)* — specialist lenses GSD lacks: strategy (`office-hours`), plan reviews, live browser QA
- **superpowers** *(Claude only)* — TDD / verification, applied automatically inside execution

## PC-wide guidelines (always-on, per selected runtime)

The installer also writes an **always-on instruction block** that applies across every project on the machine, to whichever runtime(s) you selected:

- **Claude Code** → `~/.claude/CLAUDE.md`
- **Codex** → `~/.codex/AGENTS.md`

The block:

> - **사용자 조작 최소화** — require the absolute minimum manual work from the user; the LLM handles install, config, coding, verification, and debugging end to end.
> - **불가피한 사용자 조작** — when a step genuinely needs the user (login, payment, 2FA, granting external permissions), don't just hand it off: find and spell out the **easiest** way for them to do it (exact location, command, copy-paste-ready value).

It's wrapped in `<!-- TRIPLE-CROWN GUIDELINES … -->` markers and updated **idempotently** — re-running the installer replaces only that block, leaving the rest of your `CLAUDE.md` / `AGENTS.md` untouched.

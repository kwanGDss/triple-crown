# triple-crown

One-command setup for the Triple Crown AI dev workflow — **GSD (gsd-core) + gstack + superpowers + the `/start` command** — on Claude Code and Codex.

## Install (macOS / Linux / WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/kwanGDss/triple-crown/main/install.sh | bash
```

> **Windows:** run this **inside WSL** (Ubuntu). Native Windows shell is not supported.

The installer is self-contained — the `/start` skill is embedded, no extra downloads.

### Prerequisites (install inside the same environment first)
- **Claude Code** CLI, installed **and logged in**
- **Node.js 18+** (`node`/`npx`)
- **git**

The installer auto-handles **bun** (bootstraps it) and installs gstack, superpowers, GSD, and `/start`.
`codex` is optional — if present, GSD + `/start` install for it too. On WSL, GSD hooks use `--portable-hooks`.

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

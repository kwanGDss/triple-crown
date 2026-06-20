#!/usr/bin/env bash
# ============================================================================
# Triple Crown installer — gstack + superpowers + GSD (gsd-core) + /start
# Portable: macOS, Linux, WSL.   On native Windows, run this inside WSL.
# Usage:  bash install.sh
# Self-contained: the /start skill is embedded below (no network fetch for it).
# ============================================================================
set -uo pipefail

g=$'\033[32m'; y=$'\033[33m'; r=$'\033[31m'; z=$'\033[0m'
ok(){   printf "${g}OK${z}  %s\n" "$1"; }
warn(){ printf "${y}!! ${z} %s\n" "$1"; }
 err(){  printf "${r}xx${z} %s\n" "$1"; }
have(){ command -v "$1" >/dev/null 2>&1; }

echo "=== Triple Crown installer ==="

# ---- OS detect ----
case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then OS=wsl; else OS=linux; fi ;;
  *)      OS=other ;;
esac
echo "OS: $OS"
if [ "$OS" = other ]; then
  err "Unsupported environment. On Windows, run this inside WSL (Ubuntu)."; exit 1
fi

# ---- prerequisites the user must provide ----
MISS=0
have claude || { err "Claude Code CLI missing. Install + log in: https://docs.anthropic.com/en/docs/claude-code"; MISS=1; }
{ have node && have npx; } || { err "Node.js/npx missing. Install Node 18+: https://nodejs.org (or nvm)."; MISS=1; }
have git || { err "git missing. Install git."; MISS=1; }
if [ "$MISS" = 1 ]; then echo; err "Install the prerequisites above, then re-run. (Claude Code must be logged in.)"; exit 1; fi
ok "prereqs: claude, node/npx, git"
if have codex; then ok "codex detected — GSD will also install for Codex"; else warn "codex not found — skipping Codex (optional)"; fi

# ---- bun (needed by gstack ./setup) — bootstrap if missing ----
if ! have bun; then
  warn "bun missing — installing (gstack needs it)..."
  curl -fsSL https://bun.sh/install | bash || warn "bun install failed"
  export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"
fi
have bun && ok "bun ready" || warn "bun unavailable — gstack will be skipped"

# ---- 1) gstack (Claude Code only; official install) ----
GS="$HOME/.claude/skills/gstack"
if [ -d "$GS/.git" ]; then
  echo "gstack present — updating..."; ( cd "$GS" && git pull --quiet && ./setup ) && ok "gstack updated" || warn "gstack update issues"
elif have bun; then
  echo "Installing gstack..."
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$GS" \
    && ( cd "$GS" && ./setup ) && ok "gstack installed" || warn "gstack install issues (continuing)"
else
  warn "skipping gstack (no bun). GSD spine works; gstack lenses are optional extras."
fi

# ---- 2) superpowers (Claude plugin) ----
echo "Installing superpowers..."
claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
claude plugin install superpowers@claude-plugins-official >/dev/null 2>&1 && ok "superpowers installed" || warn "superpowers install issues (is Claude logged in?)"

# ---- 3) GSD (gsd-core) for Claude (+ Codex) ----
echo "Installing GSD (gsd-core)..."
# On WSL (and Docker bind-mounts), make hook paths $HOME-relative so settings.json stays portable.
PH=""; [ "$OS" = wsl ] && { PH="--portable-hooks"; echo "  (WSL: using --portable-hooks)"; }
npx -y @opengsd/gsd-core@latest --claude --global $PH >/dev/null 2>&1 && ok "GSD -> Claude Code" || warn "GSD (claude) install issues"
if have codex; then
  npx -y @opengsd/gsd-core@latest --codex --global $PH >/dev/null 2>&1 && ok "GSD -> Codex" || warn "GSD (codex) install issues"
fi

# ---- 4) /start command (embedded skill) ----
write_skill(){
  local dst="$1"; mkdir -p "$(dirname "$dst")"
  cat > "$dst" <<'SKILL_EOF'
---
name: start
description: Full Triple Crown for a project — validate → scaffold → build → test, run end to end (attended, you at the keyboard). Uses GSD's current canonical lifecycle (spec→discuss→plan→execute→verify) as the spine, with gstack specialist lenses layered in. Stops after tests pass, before shipping (opening the PR is the final manual step). Cross-runtime (Claude Code + Codex). Use to "start a project" / "/start <idea>". Flags — --bootstrap: stop after scaffold (design only); --fast: skip strategy validation.
argument-hint: "\"<project idea>\" [--bootstrap] [--fast]"
allowed-tools:
  - Skill
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /start — full Triple Crown (current GSD lifecycle)

Idea → tested code, one command, attended. Hand-authored (not part of gsd-core — `/gsd-update`
won't touch it). **Scope:** `validate → scaffold → build → test`, then STOP before ship
(`/gsd-ship` is the human's last step). Unattended version: `/loopstart`.

**Flags:** `--bootstrap` stop after scaffold (design only) · `--fast` skip strategy validation.

## Design — current tool split (GSD has absorbed most of the old book flow)

- **Spine = GSD.** Per phase GSD now runs the canonical `spec → discuss → plan → execute → verify`
  (verify is a *closed* loop: auto-diagnoses failures, writes gap-closure fixes, re-executes).
  Orchestrate with **`/gsd-progress --next`** (stepwise) or **`/gsd-autonomous`** (back-to-back).
- **gstack = specialist lenses GSD lacks** (Claude Code only), layered at the right gates:
  strategy validation (`office-hours`), plan pressure-tests (`plan-ceo/eng/design/devex-review`),
  live browser QA (`qa`), code-quality dashboard (`health`).
- **superpowers applies automatically** inside `gsd-execute-phase` (TDD, verification gates,
  subagent waves) — no explicit wiring. Reach for `receiving-code-review` / `systematic-debugging` only if needed.
- **Do NOT double-stack the redundant gstack skills:** `spec` (=gsd-spec-phase), `review`
  (=gsd-code-review), `investigate` (=gsd-debug) are superseded by GSD — skip them.

`$ARGUMENTS` = the project idea (quoted) + optional flags.

---

## Step 0 — One-time process standardization (global, all projects)

```bash
test -f ~/.gsd/triple-crown.json && echo INIT_DONE || echo INIT_NEEDED
```
- **INIT_NEEDED:** first project — run **`gsd-config`** so the user sets standard toggles ONCE
  (model profile, research, plan_check, verifier, branching). Then:
  ```bash
  mkdir -p ~/.gsd && printf '{"version":1,"workflow":"triple-crown"}' > ~/.gsd/triple-crown.json
  ```
- **INIT_DONE:** skip.

## Step 1 — Validate the idea (strategy)  *(skip if `--fast`)*

- **Claude Code:** run **`office-hours`** — adversarial demand validation, the 10-star wedge → design doc.
- **Codex / non-Claude:** run **`gsd-explore`** — Socratic ideation (gstack is unavailable there).

Carry the conclusion into Step 2.

## Step 2 — Scaffold the project (GSD)

Run **`gsd-new-project`** using the Step 1 framing as context (don't re-ask what it settled).
Result: `.planning/` with REQUIREMENTS.md + ROADMAP.md. Ensure it's a git repo (`git init` if needed).

> **If `--bootstrap`:** print the roadmap + next steps and **STOP here** (design only).

## Step 3 — Build & test every phase (GSD spine + gstack lenses)

Drive each roadmap phase to a **verified** state. Use GSD's canonical per-phase flow — run
**`/gsd-autonomous`** to go phase-to-phase, or **`/gsd-progress --next`** one step at a time.
GSD does, per phase: `spec-phase → discuss-phase → plan-phase → execute-phase → verify-work`
(verify auto-loops fixes until UAT passes). superpowers TDD/verification/subagent-waves apply automatically inside execute.

Layer the gstack lenses at the gates **(Claude Code only)**:
- **After `plan-phase`, before `execute-phase`** — pressure-test the PLAN.md with the lens that fits the phase
  (point the review at the GSD `PLAN.md`):
  - `plan-ceo-review` — scope/strategy ambition (worth it on most phases)
  - `plan-eng-review` — backend/architecture failure modes & observability
  - `plan-design-review` — UI phases; generates real mockups to compare
  - `plan-devex-review` — when the deliverable is an API/CLI/SDK/library
  - (`autoplan` can run these lenses as a batch.)
- **At `verify-work`, for web apps** — add **`qa`** (live browser: real flows, console errors, regression baselines) on top of GSD's conversational UAT.
- **Anytime** — **`health`** for a typecheck/lint/test/deadcode quality score + trend.

Commit atomically per phase on a phase branch; do **not** merge to the base branch.

## Step 4 — Stop after tests (before ship)

When all phases are built and **verified**, STOP. Summarize: phases completed, tests green/red, open items.
The final step is the human's:

> **"Built & tested. Ship the PR with `/gsd-ship` when you're ready."**

Do NOT ship / merge / deploy automatically — **tested-but-not-shipped** is this command's endpoint.
SKILL_EOF
  ok "/start -> $dst"
}
write_skill "$HOME/.claude/skills/start/SKILL.md"
have codex && write_skill "$HOME/.codex/skills/start/SKILL.md"

# ---- 5) global process marker (every project same process) ----
mkdir -p "$HOME/.gsd"
[ -f "$HOME/.gsd/triple-crown.json" ] || printf '{"version":1,"workflow":"triple-crown"}' > "$HOME/.gsd/triple-crown.json"

echo
ok "Done. Restart Claude Code (or Codex), then:   /start \"<your idea>\""
echo "    GSD + /start work on Claude Code and Codex. gstack lenses are Claude-only."
[ "$OS" = wsl ] && echo "    (WSL: installed under your WSL home, not Windows C:\\.)"

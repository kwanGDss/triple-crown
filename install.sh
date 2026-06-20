#!/usr/bin/env bash
# ============================================================================
# Triple Crown installer — gstack + superpowers + GSD (gsd-core) + /start + guidelines
# Portable: macOS, Linux, WSL.   On native Windows, run this inside WSL.
# Usage:  bash install.sh    — interactive: pick Claude Code and/or Codex, then it installs.
# Prereqs: curl + git + the runtime CLI you pick (logged in). Node 18+ is auto-installed (nvm) if missing.
# Self-contained: the /start skill + PC-wide guidelines are embedded below (no network fetch).
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

# ---- prerequisites: curl + a WORKING git; Node is auto-installed (via nvm) if missing ----
have curl || { err "curl missing. Install curl, then re-run."; exit 1; }
# git --version (not just `command -v`) so the macOS Command Line Tools STUB doesn't pass falsely.
if ! git --version >/dev/null 2>&1; then
  echo; err "git not available (on macOS it may be only the Command Line Tools stub). Install it, then re-run:"
  err "  Debian/Ubuntu/WSL:  sudo apt update && sudo apt install -y git"
  err "  Fedora:             sudo dnf install -y git"
  err "  macOS:              xcode-select --install"
  exit 1
fi
# Node 18+ (GSD installs via npx). Auto-bootstrap the LTS via nvm if missing — same spirit as bun.
if ! { have node && have npx; }; then
  warn "Node.js/npx missing — installing the LTS via nvm..."
  export NVM_DIR="$HOME/.nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash || warn "nvm install failed"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  command -v nvm >/dev/null 2>&1 && { nvm install --lts >/dev/null 2>&1; nvm use --lts >/dev/null 2>&1; }
fi
if ! { have node && have npx; }; then
  echo; err "Node.js/npx still missing. Install Node 18+ then re-run:  https://nodejs.org  (or nvm)"; exit 1
fi
# Enforce major >= 18 (presence alone isn't enough for gsd-core). bash-3.2 / POSIX-safe parsing.
NODE_MAJOR="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
case "$NODE_MAJOR" in
  ''|*[!0-9]*) warn "Could not read Node version ($(node -v 2>/dev/null)) — proceeding." ;;
  *) [ "$NODE_MAJOR" -ge 18 ] || { echo; err "Node $(node -v) found, but 18+ is required. Upgrade (e.g. nvm install --lts), then re-run."; exit 1; } ;;
esac
ok "prereqs: curl, git, node $(node -v 2>/dev/null)"

# ---- choose runtime(s) to set up: Claude Code and/or Codex ----
# Interactive: pick one or BOTH. Reads the terminal even under `curl | bash` (stdin is the script there).
# Verify the tty can actually be OPENED (Git Bash stats /dev/tty readable but cannot open it -> would loop).
if ! (exec 3</dev/tty) 2>/dev/null; then
  err "No interactive terminal available. Run this in a real terminal (mac/Linux/WSL)."; exit 1
fi
WANT_CLAUDE=0; WANT_CODEX=0
while [ "$WANT_CLAUDE" = 0 ] && [ "$WANT_CODEX" = 0 ]; do
  echo
  echo "Set up which runtime(s)?  (you can pick BOTH)"
  echo "   1) Claude Code"
  echo "   2) Codex"
  echo "   3) Both"
  printf "Enter 1, 2, or 3: "
  read -r ans < /dev/tty || { echo; err "Could not read your choice from the terminal."; exit 1; }
  case "$ans" in
    1)             WANT_CLAUDE=1 ;;
    2)             WANT_CODEX=1 ;;
    3|"1 2"|"2 1") WANT_CLAUDE=1; WANT_CODEX=1 ;;
    *)             warn "Please enter 1, 2, or 3." ;;
  esac
done
[ "$WANT_CLAUDE" = 1 ] && ok "selected: Claude Code"
[ "$WANT_CODEX"  = 1 ] && ok "selected: Codex"

# Heads-up if a chosen runtime's CLI isn't installed (file-based parts still install).
if [ "$WANT_CLAUDE" = 1 ] && ! have claude; then
  warn "Claude Code CLI not found on PATH — install + log in (https://docs.anthropic.com/en/docs/claude-code). superpowers needs it; the rest still installs."
fi
if [ "$WANT_CODEX" = 1 ] && ! have codex; then
  warn "Codex CLI not found on PATH — install + log in. \$start needs it; the rest still installs."
fi
# WSL split-brain: if the only `claude` is the Windows install (via /mnt interop), plugins land in Windows ~/.claude.
if [ "$WANT_CLAUDE" = 1 ] && [ "$OS" = wsl ] && have claude; then
  case "$(readlink -f "$(command -v claude)" 2>/dev/null)" in
    /mnt/*) warn "Your 'claude' is the Windows install (via /mnt interop): superpowers would land in Windows ~/.claude while the rest installs in WSL — split setup. For one consistent home, install Claude natively in WSL:  npm i -g @anthropic-ai/claude-code" ;;
  esac
fi

FAILED=0   # count load-bearing (GSD) failures so the final summary is honest

# ---- bun (needed by gstack ./setup, Claude-only) — bootstrap if missing ----
if [ "$WANT_CLAUDE" = 1 ]; then
  if ! have bun; then
    warn "bun missing — installing (gstack needs it)..."
    curl -fsSL https://bun.sh/install | bash || warn "bun install failed"
    export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"
  fi
  have bun && ok "bun ready" || warn "bun unavailable — gstack will be skipped"
fi

# ---- 1) gstack (Claude Code only; official install) ----
if [ "$WANT_CLAUDE" = 1 ]; then
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
fi

# ---- 2) superpowers (Claude plugin) ----
if [ "$WANT_CLAUDE" = 1 ]; then
  if ! have claude; then
    warn "superpowers skipped — 'claude' CLI not found (install Claude Code + re-run)."
  else
    echo "Installing superpowers..."
    claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
    claude plugin install superpowers@claude-plugins-official >/dev/null 2>&1 && ok "superpowers installed" || warn "superpowers install issues (is 'claude' logged in? try: claude login)"
  fi
fi

# ---- 3) GSD (gsd-core) for Claude and/or Codex ----
echo "Installing GSD (gsd-core)..."
# On WSL (and Docker bind-mounts), make hook paths $HOME-relative so settings.json stays portable.
PH=""; [ "$OS" = wsl ] && { PH="--portable-hooks"; echo "  (WSL: using --portable-hooks)"; }
if [ "$WANT_CLAUDE" = 1 ]; then
  npx -y @opengsd/gsd-core@latest --claude --global $PH >/dev/null 2>&1 && ok "GSD -> Claude Code" || { warn "GSD (claude) install issues"; FAILED=$((FAILED+1)); }
fi
if [ "$WANT_CODEX" = 1 ]; then
  npx -y @opengsd/gsd-core@latest --codex --global $PH >/dev/null 2>&1 && ok "GSD -> Codex" || { warn "GSD (codex) install issues"; FAILED=$((FAILED+1)); }
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
[ "$WANT_CLAUDE" = 1 ] && write_skill "$HOME/.claude/skills/start/SKILL.md"
[ "$WANT_CODEX"  = 1 ] && write_skill "$HOME/.codex/skills/start/SKILL.md"

# ---- 4.5) PC-wide guidelines (managed block; cross-runtime: Claude + Codex) ----
# Always-on instructions injected into every session. Idempotent: only the block
# between the markers is replaced on re-run; any other content the user already has
# in CLAUDE.md / AGENTS.md is preserved.
GUIDE_BEGIN="<!-- TRIPLE-CROWN GUIDELINES — managed by install.sh; re-running replaces ONLY this block -->"
GUIDE_END="<!-- /TRIPLE-CROWN GUIDELINES -->"
upsert_guidelines(){
  local f="$1" label="$2"; mkdir -p "$(dirname "$f")"; touch "$f"
  local tmp; tmp="$(mktemp)"
  awk -v b="$GUIDE_BEGIN" -v e="$GUIDE_END" '
    $0==b{skip=1} skip==0{print} $0==e{skip=0}' "$f" > "$tmp"   # strip old block, keep rest
  { cat "$tmp"; printf '\n%s\n' "$GUIDE_BEGIN"; cat <<'GUIDE_EOF'
## Triple Crown — 작업 원칙 (PC 전역, 모든 프로젝트에 적용)

- **사용자 조작 최소화**: 사용자에게 요구하는 수작업을 극히 최소한으로 줄인다.
  설치·설정·코드 작성·검증·디버깅 등 웬만한 작업은 LLM이 직접 끝까지 처리한다.
- **불가피한 사용자 조작**: 진행 도중 반드시 사용자의 직접 조작이 필요한 지점
  (로그인·결제·2FA·외부 권한 승인 등)을 만나면, 그냥 떠넘기지 말고
  **사용자가 가장 쉽고 빠르게 적용할 수 있는 방안**을 찾아 구체적으로 안내한다
  (정확한 위치·명령어·복사해 붙여넣을 수 있는 값까지 제시).
GUIDE_EOF
    printf '%s\n' "$GUIDE_END"; } > "$f"
  rm -f "$tmp"; ok "guidelines -> $f ($label)"
}
[ "$WANT_CLAUDE" = 1 ] && upsert_guidelines "$HOME/.claude/CLAUDE.md" "Claude Code"
[ "$WANT_CODEX"  = 1 ] && upsert_guidelines "$HOME/.codex/AGENTS.md" "Codex"

# ---- 5) global process marker (every project same process) ----
mkdir -p "$HOME/.gsd"
[ -f "$HOME/.gsd/triple-crown.json" ] || printf '{"version":1,"workflow":"triple-crown"}' > "$HOME/.gsd/triple-crown.json"

echo
if [ "${FAILED:-0}" -gt 0 ]; then
  err "Finished with $FAILED problem(s): GSD (the spine) did not fully install — see the !! line(s) above."
  echo "    Common causes: no network, or the runtime CLI not installed/logged in. Fix it and re-run (safe to repeat)."
  [ "$WANT_CLAUDE" = 1 ] && echo "    Claude guidelines written -> ~/.claude/CLAUDE.md"
  [ "$WANT_CODEX"  = 1 ] && echo "    Codex  guidelines written -> ~/.codex/AGENTS.md"
  exit 1
fi
ok "Done. Restart your runtime, then:   /start \"<your idea>\"  (Claude)   ·   \$start \"<your idea>\"  (Codex)"
echo "    Installed for your selected runtime(s) — GSD + /start + guidelines each; gstack/superpowers are Claude-only."
[ "$WANT_CLAUDE" = 1 ] && echo "    Claude guidelines -> ~/.claude/CLAUDE.md"
[ "$WANT_CODEX"  = 1 ] && echo "    Codex  guidelines -> ~/.codex/AGENTS.md"
[ "$OS" = wsl ] && echo "    (WSL: installed under your WSL home, not Windows C:\\.)"
exit 0

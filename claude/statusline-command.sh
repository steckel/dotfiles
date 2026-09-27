#!/bin/sh
# Claude Code status line — reads session JSON on stdin and prints a
# single-line status with: PS1-style prefix, model, git branch, context %,
# and session cost. Falls back gracefully when fields are missing.

input=$(cat)

field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

# --- ANSI colors (256-color) ---
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RED=$'\033[38;5;203m'
YEL=$'\033[38;5;221m'
GRN=$'\033[38;5;114m'
CYA=$'\033[38;5;110m'
MAG=$'\033[38;5;176m'
GRY=$'\033[38;5;245m'

# --- PS1-style prefix (redhat theme) ---
prefix=$(printf '[%s@%s %s]' "$(whoami)" "$(hostname -s)" "$(basename "$(pwd)")")

# --- Model ---
model=$(field '.model.display_name')
[ -z "$model" ] && model=$(field '.model.id')

# --- Git branch (prefer cwd, fall back to JSON) ---
branch=$(git -C "$(pwd)" symbolic-ref --short HEAD 2>/dev/null)
[ -z "$branch" ] && branch=$(field '.workspace.current_dir | .git.branch')

# --- Context window ---
ctx_pct=$(field '.context_window.used_percentage')
ctx_used=$(field '.context_window.total_input_tokens')
ctx_max=$(field '.context_window.context_window_size')

# Color the % by pressure
ctx_color=$GRN
case "$ctx_pct" in
  ''|null) ctx_color=$DIM ;;
  *)
    pct_int=${ctx_pct%.*}
    [ "$pct_int" -ge 60 ] 2>/dev/null && ctx_color=$YEL
    [ "$pct_int" -ge 85 ] 2>/dev/null && ctx_color=$RED
    ;;
esac

# Format token counts as e.g. 42k / 200k
human() {
  n=$1
  [ -z "$n" ] || [ "$n" = "null" ] && { printf '?'; return; }
  if [ "$n" -ge 1000 ] 2>/dev/null; then
    printf '%dk' $((n / 1000))
  else
    printf '%s' "$n"
  fi
}

# --- Cost ---
cost=$(field '.cost.total_cost_usd')

# --- Compose ---
out="${GRY}${prefix}${RESET}"
[ -n "$model" ]  && out="$out  ${CYA}${model}${RESET}"
[ -n "$branch" ] && out="$out  ${MAG}⎇ ${branch}${RESET}"
if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
  out="$out  ${ctx_color}ctx ${ctx_pct%.*}%${RESET}${DIM}($(human "$ctx_used")/$(human "$ctx_max"))${RESET}"
fi
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  out="$out  ${GRN}\$$(printf '%.4f' "$cost" 2>/dev/null || printf '%s' "$cost")${RESET}"
fi

printf '%s' "$out"

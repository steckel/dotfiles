#!/usr/bin/env bash
# Set or clear the tmux @busy window flag from a Claude Code hook.
# $TMUX_PANE is inherited from the pane that launched `claude`; outside
# tmux this is a no-op.

[ -n "${TMUX_PANE:-}" ] || exit 0

case "${1:-}" in
  on)  tmux set-option -w -t "$TMUX_PANE" @busy 1 2>/dev/null ;;
  off) tmux set-option -u -w -t "$TMUX_PANE" @busy 2>/dev/null ;;
esac

exit 0

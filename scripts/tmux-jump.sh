#!/bin/bash
# tmux-jump.sh — Switch tmux client to target session:window.pane
# Called from Windows-side tmux-jump.ps1 via wsl.exe
TARGET="$1"
[ -z "$TARGET" ] && exit 1

SESSION="${TARGET%%:*}"
WINDOW_PANE="${TARGET#*:}"
WINDOW="${WINDOW_PANE%%.*}"
PANE="${WINDOW_PANE#*.}"

# Find the most recently active tmux client
CLIENT=$(tmux list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | cut -d' ' -f2-)
[ -z "$CLIENT" ] && exit 1

# Switch client to target session, select window, then select pane
tmux switch-client -c "$CLIENT" -t "$SESSION" 2>/dev/null
tmux select-window -t "${SESSION}:${WINDOW}" 2>/dev/null
tmux select-pane -t "${SESSION}:${WINDOW}.${PANE}" 2>/dev/null

# Exit copy mode if active
IN_MODE=$(tmux display-message -t "${SESSION}:${WINDOW}.${PANE}" -p '#{pane_in_mode}' 2>/dev/null)
[ "$IN_MODE" = "1" ] && tmux send-keys -t "${SESSION}:${WINDOW}.${PANE}" q
exit 0

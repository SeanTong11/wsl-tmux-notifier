#!/bin/bash
# wsl-tmux-notify.sh — Claude Code hook notification script
# Uses BurntToast via PowerShell -EncodedCommand for proper Unicode support.

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD/#$HOME/\~}"

# Windows-side directory for icon and other assets
WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_DIR_NAME=".wsl-tmux-notifier"
LEGACY_WIN_DIR_NAME=".wsl-claude-notifier"
WSL_ICON="/mnt/c/Users/${WIN_USER}/${WIN_DIR_NAME}/icon.png"
if [ -f "$WSL_ICON" ]; then
  WIN_ICON="C:\\Users\\${WIN_USER}\\${WIN_DIR_NAME}\\icon.png"
else
  WIN_ICON="C:\\Users\\${WIN_USER}\\${LEGACY_WIN_DIR_NAME}\\icon.png"
fi

# Get tmux session:window for identification, fallback to dir basename
if [ -n "$TMUX" ]; then
  SESS=$(tmux display-message -p '#{session_name}' 2>/dev/null)
  WIN=$(tmux display-message -p '#{window_name}' 2>/dev/null)
  WIN_IDX=$(tmux display-message -p '#{window_index}' 2>/dev/null)
  PANE_IDX=$(tmux display-message -p '#{pane_index}' 2>/dev/null)
  WIN="${WIN#\[}"; WIN="${WIN%\]}"
  TAG="${SESS}:${WIN}"
  JUMP_URI="tmux-jump://${SESS}:${WIN_IDX}.${PANE_IDX}"
else
  TAG="${CWD##*/}"
  JUMP_URI=""
fi

case "$EVENT" in
  Stop)
    MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' | tr '\n' ' ' | cut -c1-80)
    TITLE="[${TAG}] Done"
    BODY="${MSG:-Task complete}"
    ;;
  Notification)
    MSG=$(echo "$INPUT" | jq -r '.message // empty' | tr '\n' ' ' | cut -c1-80)
    TITLE="[${TAG}] Attention"
    BODY="${MSG:-Needs input}"
    ;;
  *)
    TITLE="[${TAG}] Claude"
    BODY="$EVENT"
    ;;
esac

# Escape single quotes for PowerShell string embedding
TITLE="${TITLE//\'/\'\'}"
BODY="${BODY//\'/\'\'}"

# Build PowerShell command using BurntToast (with optional Jump button for tmux)
if [ -n "$JUMP_URI" ]; then
  PS_SCRIPT="Import-Module BurntToast; \$btn = New-BTButton -Content 'Jump' -Arguments '${JUMP_URI}' -ActivationType Protocol; New-BurntToastNotification -Text '${TITLE}', '${BODY}' -Button \$btn -AppLogo '${WIN_ICON}' -Sound Default"
else
  PS_SCRIPT="Import-Module BurntToast; New-BurntToastNotification -Text '${TITLE}', '${BODY}' -AppLogo '${WIN_ICON}' -Sound Default"
fi

# Encode as UTF-16LE base64 to preserve Unicode through WSL->Windows boundary
ENCODED=$(printf '%s' "$PS_SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)
# Use setsid to detach from hook process group (avoid being killed by hook timeout)
setsid powershell.exe -NoProfile -EncodedCommand "$ENCODED" >/dev/null 2>&1 &

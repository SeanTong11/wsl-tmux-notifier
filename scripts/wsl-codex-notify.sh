#!/bin/bash
# wsl-codex-notify.sh — Codex CLI notification script
# Codex passes JSON as the last argv argument (with stdin as fallback).
# Uses BurntToast via PowerShell -EncodedCommand for proper Unicode support.

# Prefer the last argv item; fallback to stdin for compatibility.
INPUT=""
if [ "$#" -gt 0 ]; then
  INPUT="${!#}"
fi
if [ -z "$INPUT" ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
fi
[ -z "$INPUT" ] && exit 0

# Optional debug log to inspect real payloads from Codex.
LOG_FILE="${WSL_CODEX_NOTIFY_LOG:-/tmp/wsl-codex-notify.log}"
log() {
  printf '%s | %s\n' "$(date -Is)" "$1" >> "$LOG_FILE" 2>/dev/null || true
}

if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log "skip invalid-json argc=$#"
  exit 0
fi

EVENT_TYPE=$(echo "$INPUT" | jq -r '.type // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD/#$HOME/\~}"

# Windows-side directory for icon and other assets
WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_DIR_NAME=".wsl-tmux-notifier"
LEGACY_WIN_DIR_NAME=".wsl-claude-notifier"
WIN_ICON_CODEX="C:\\Users\\${WIN_USER}\\${WIN_DIR_NAME}\\codex-icon.png"
WIN_ICON_FALLBACK="C:\\Users\\${WIN_USER}\\${WIN_DIR_NAME}\\icon.png"
WSL_ICON_CODEX="/mnt/c/Users/${WIN_USER}/${WIN_DIR_NAME}/codex-icon.png"
LEGACY_WIN_ICON_CODEX="C:\\Users\\${WIN_USER}\\${LEGACY_WIN_DIR_NAME}\\codex-icon.png"
LEGACY_WIN_ICON_FALLBACK="C:\\Users\\${WIN_USER}\\${LEGACY_WIN_DIR_NAME}\\icon.png"
WSL_ICON_FALLBACK="/mnt/c/Users/${WIN_USER}/${WIN_DIR_NAME}/icon.png"
WSL_LEGACY_ICON_CODEX="/mnt/c/Users/${WIN_USER}/${LEGACY_WIN_DIR_NAME}/codex-icon.png"
if [ -f "$WSL_ICON_CODEX" ]; then
  WIN_ICON="$WIN_ICON_CODEX"
elif [ -f "$WSL_ICON_FALLBACK" ]; then
  WIN_ICON="$WIN_ICON_FALLBACK"
elif [ -f "$WSL_LEGACY_ICON_CODEX" ]; then
  WIN_ICON="$LEGACY_WIN_ICON_CODEX"
else
  WIN_ICON="$LEGACY_WIN_ICON_FALLBACK"
fi

# Get tmux session:window for identification, fallback to dir basename
if [ -n "${TMUX:-}" ]; then
  SESS=$(tmux display-message -p '#{session_name}' 2>/dev/null)
  WIN=$(tmux display-message -p '#{window_name}' 2>/dev/null)
  WIN_IDX=$(tmux display-message -p '#{window_index}' 2>/dev/null)
  PANE_IDX=$(tmux display-message -p '#{pane_index}' 2>/dev/null)
  if [ -n "$SESS" ] && [ -n "$WIN_IDX" ] && [ -n "$PANE_IDX" ]; then
    WIN="${WIN#\[}"; WIN="${WIN%\]}"
    TAG="${SESS}:${WIN:-$WIN_IDX}"
    JUMP_URI="tmux-jump://${SESS}:${WIN_IDX}.${PANE_IDX}"
  else
    TAG="${CWD##*/}"
    JUMP_URI=""
  fi
else
  TAG="${CWD##*/}"
  JUMP_URI=""
fi
[ -z "$TAG" ] && TAG="codex"

case "$EVENT_TYPE" in
  agent-turn-complete)
    # Codex payload uses kebab-case; keep snake_case fallback for compatibility.
    MSG=$(echo "$INPUT" | jq -r '.["last-assistant-message"] // .last_assistant_message // empty' | tr '\n' ' ' | cut -c1-80)
    TITLE="[${TAG}] Codex Done"
    BODY="${MSG:-Task complete}"
    ;;
  *)
    log "skip unsupported-event type=${EVENT_TYPE:-empty}"
    exit 0
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
log "sent type=$EVENT_TYPE tag=$TAG tmux=$([ -n "${TMUX:-}" ] && echo 1 || echo 0)"

#!/bin/bash
# uninstall-claude.sh — Remove Claude Code notification components
set -euo pipefail

WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
BIN_DIR="$HOME/.local/bin"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "=== wsl-tmux-notifier uninstaller (Claude Code) ==="
echo ""

# Step 1: Remove registry protocol
echo "[1/4] Removing tmux-jump:// protocol from registry..."
UNREG_SCRIPT='Remove-Item -Path "HKCU:\Software\Classes\tmux-jump" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  OK: registry cleaned"'
ENCODED=$(printf '%s' "$UNREG_SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)
powershell.exe -NoProfile -EncodedCommand "$ENCODED"

# Step 2: Remove Windows-side files (current + legacy directory names)
echo "[2/4] Removing Windows-side files..."
for dir in \
  "/mnt/c/Users/${WIN_USER}/.wsl-tmux-notifier" \
  "/mnt/c/Users/${WIN_USER}/.wsl-claude-notifier" \
  "/mnt/c/Users/${WIN_USER}/.wsl-tmux-notify"
do
  if [ -d "$dir" ]; then
    rm -r "$dir"
    echo "  OK: removed $dir"
  fi
done
echo "  Done"

# Step 3: Remove WSL-side scripts
echo "[3/4] Removing scripts from ${BIN_DIR}/..."
for f in wsl-tmux-notify.sh tmux-jump.sh; do
  if [ -f "$BIN_DIR/$f" ]; then
    rm "$BIN_DIR/$f"
    echo "  OK: removed $f"
  else
    echo "  SKIP: $f not found"
  fi
done

# Step 4: Remove hooks from Claude Code settings
echo "[4/4] Removing hooks from Claude Code settings..."
if [ -f "$CLAUDE_SETTINGS" ] && grep -q "wsl-tmux-notify" "$CLAUDE_SETTINGS" 2>/dev/null; then
  TMP=$(mktemp)
  jq 'del(.hooks.Stop, .hooks.Notification)' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
  # Remove empty hooks object if nothing else remains
  if [ "$(jq '.hooks | length' "$CLAUDE_SETTINGS" 2>/dev/null)" = "0" ]; then
    TMP=$(mktemp)
    jq 'del(.hooks)' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
  fi
  echo "  OK: hooks removed from $CLAUDE_SETTINGS"
else
  echo "  SKIP: no hooks found"
fi

echo ""
echo "=== Uninstall complete ==="

#!/bin/bash
# uninstall-codex.sh — Remove Codex CLI notification components
set -euo pipefail

WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
BIN_DIR="$HOME/.local/bin"
CODEX_CONFIG="$HOME/.codex/config.toml"

echo "=== wsl-tmux-notifier uninstaller (Codex CLI) ==="
echo ""

# Step 1: Remove registry protocol
echo "[1/4] Removing tmux-jump:// protocol from registry..."
UNREG_SCRIPT='Remove-Item -Path "HKCU:\Software\Classes\tmux-jump" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  OK: registry cleaned"'
ENCODED=$(printf '%s' "$UNREG_SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)
powershell.exe -NoProfile -EncodedCommand "$ENCODED"

# Step 2: Remove Windows-side files (current + legacy directory names)
echo "[2/4] Removing Windows-side files..."
REMOVED=0
for dir in \
  "/mnt/c/Users/${WIN_USER}/.wsl-tmux-notifier" \
  "/mnt/c/Users/${WIN_USER}/.wsl-claude-notifier" \
  "/mnt/c/Users/${WIN_USER}/.wsl-tmux-notify"
do
  if [ -d "$dir" ]; then
    rm -r "$dir"
    echo "  OK: removed $dir"
    REMOVED=1
  fi
done
[ "$REMOVED" -eq 0 ] && echo "  SKIP: directory not found"

# Step 3: Remove WSL-side scripts
echo "[3/4] Removing scripts from ${BIN_DIR}/..."
for f in wsl-codex-notify.sh tmux-jump.sh; do
  if [ -f "$BIN_DIR/$f" ]; then
    rm "$BIN_DIR/$f"
    echo "  OK: removed $f"
  else
    echo "  SKIP: $f not found"
  fi
done

# Step 4: Remove notify from Codex config
echo "[4/4] Removing notify from Codex config..."
if [ -f "$CODEX_CONFIG" ] && grep -q "wsl-codex-notify" "$CODEX_CONFIG" 2>/dev/null; then
  TMP=$(mktemp)
  grep -v "wsl-codex-notify" "$CODEX_CONFIG" > "$TMP" && mv "$TMP" "$CODEX_CONFIG"
  # Remove empty file if nothing remains
  if [ ! -s "$CODEX_CONFIG" ]; then
    rm "$CODEX_CONFIG"
    echo "  OK: removed empty $CODEX_CONFIG"
  else
    echo "  OK: notify removed from $CODEX_CONFIG"
  fi
else
  echo "  SKIP: no notify config found"
fi

echo ""
echo "=== Uninstall complete ==="

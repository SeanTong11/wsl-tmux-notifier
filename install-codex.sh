#!/bin/bash
# install-codex.sh — Installer for Codex CLI notifications in WSL2
# Run from WSL inside the cloned repo directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_DIR_NAME=".wsl-tmux-notifier"
WIN_DIR="C:\\Users\\${WIN_USER}\\${WIN_DIR_NAME}"
WSL_WIN_DIR="/mnt/c/Users/${WIN_USER}/${WIN_DIR_NAME}"
BIN_DIR="$HOME/.local/bin"
CODEX_CONFIG="$HOME/.codex/config.toml"

echo "=== wsl-tmux-notifier installer (Codex CLI) ==="
echo ""

# ── Step 1: Check/install BurntToast ──────────────────────────────────────────
echo "[1/5] Checking BurntToast PowerShell module..."
HAS_BT=$(powershell.exe -NoProfile -Command "if (Get-Module -ListAvailable BurntToast) { 'yes' } else { 'no' }" 2>/dev/null | tr -d '\r')
if [ "$HAS_BT" = "yes" ]; then
  echo "  OK: BurntToast already installed"
else
  echo "  Installing BurntToast..."
  powershell.exe -NoProfile -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser"
  echo "  OK: BurntToast installed"
fi

# ── Step 2: Deploy WSL-side scripts ───────────────────────────────────────────
echo "[2/5] Deploying scripts to ${BIN_DIR}/..."
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/scripts/wsl-codex-notify.sh" "$BIN_DIR/wsl-codex-notify.sh"
cp "$SCRIPT_DIR/scripts/tmux-jump.sh" "$BIN_DIR/tmux-jump.sh"
chmod +x "$BIN_DIR/wsl-codex-notify.sh" "$BIN_DIR/tmux-jump.sh"
echo "  OK: wsl-codex-notify.sh"
echo "  OK: tmux-jump.sh"

# ── Step 3: Deploy Windows-side files ─────────────────────────────────────────
echo "[3/5] Deploying Windows-side files to ${WIN_DIR}..."
mkdir -p "$WSL_WIN_DIR"
cp "$SCRIPT_DIR/windows/tmux-jump.ps1" "$WSL_WIN_DIR/tmux-jump.ps1"
cp "$SCRIPT_DIR/assets/icon.png" "$WSL_WIN_DIR/icon.png"
if [ -f "$SCRIPT_DIR/assets/codex-icon.png" ]; then
  cp "$SCRIPT_DIR/assets/codex-icon.png" "$WSL_WIN_DIR/codex-icon.png"
else
  cp "$SCRIPT_DIR/assets/icon.png" "$WSL_WIN_DIR/codex-icon.png"
fi
echo "  OK: tmux-jump.ps1"
echo "  OK: icon.png"
echo "  OK: codex-icon.png"

# ── Step 4: Register tmux-jump:// protocol ────────────────────────────────────
echo "[4/5] Registering tmux-jump:// protocol handler..."

REG_SCRIPT=$(cat <<'PSEOF'
$proto = "tmux-jump"
$handler = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\WINUSER\.wsl-tmux-notifier\tmux-jump.ps1" "%1"'
New-Item -Path "HKCU:\Software\Classes\$proto" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name "(Default)" -Value "URL:tmux-jump Protocol"
New-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name "URL Protocol" -Value "" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Name "(Default)" -Value $handler
Write-Host "  OK: tmux-jump:// protocol registered"
PSEOF
)
REG_SCRIPT="${REG_SCRIPT//WINUSER/$WIN_USER}"
ENCODED=$(printf '%s' "$REG_SCRIPT" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)
powershell.exe -NoProfile -EncodedCommand "$ENCODED"

# ── Step 5: Configure Codex CLI notify ────────────────────────────────────────
echo "[5/5] Configuring Codex CLI notifications..."

NOTIFY_CMD="$HOME/.local/bin/wsl-codex-notify.sh"
NOTIFY_LINE="notify = [\"${NOTIFY_CMD}\"]"

if [ -f "$CODEX_CONFIG" ]; then
  # Keep notify as top-level key (before any [table]) and avoid stale/invalid duplicates.
  TMP=$(mktemp)
  awk -v notify_line="$NOTIFY_LINE" '
    BEGIN { inserted = 0 }
    /^[[:space:]]*notify[[:space:]]*=/ { next }
    !inserted && /^[[:space:]]*\[/ {
      print notify_line
      print ""
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        if (NR > 0) print ""
        print notify_line
      }
    }
  ' "$CODEX_CONFIG" > "$TMP" && mv "$TMP" "$CODEX_CONFIG"
  echo "  OK: normalized notify in $CODEX_CONFIG"
else
  mkdir -p "$(dirname "$CODEX_CONFIG")"
  cat > "$CODEX_CONFIG" <<TOMLEOF
${NOTIFY_LINE}
TOMLEOF
  echo "  OK: created $CODEX_CONFIG with notify"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Verify with:"
echo "  # Test toast notification (run inside tmux for Jump button)"
echo "  ~/.local/bin/wsl-codex-notify.sh '{\"type\":\"agent-turn-complete\",\"cwd\":\"/tmp\",\"last-assistant-message\":\"Hello from Codex!\"}'"
echo ""
echo "  # Test protocol handler"
echo "  powershell.exe -Command \"Start-Process 'tmux-jump://main:0'\""

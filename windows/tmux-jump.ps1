# tmux-jump.ps1 — Protocol handler for tmux-jump:// URI
# Called by Windows when a tmux-jump:// link is activated (e.g. from toast notification)
param([string]$uri)

$logFile = "$PSScriptRoot\tmux-jump.log"

# Parse URI: tmux-jump://session:window_index.pane_index
# Don't use [System.Uri] — it treats ":N" as a port number and drops it
$target = $uri -replace '^tmux-jump://', ''
# Strip trailing slash if present
$target = $target.TrimEnd('/')

"$(Get-Date -Format o) | uri=$uri | target=$target" | Out-File -Append $logFile

if (-not $target) {
    "$(Get-Date -Format o) | ERROR: empty target" | Out-File -Append $logFile
    exit 1
}

# Bring Windows Terminal to foreground
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
$wt = Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wt) {
    [Win32]::SetForegroundWindow($wt.MainWindowHandle) | Out-Null
    "$(Get-Date -Format o) | WT activated: pid=$($wt.Id)" | Out-File -Append $logFile
} else {
    "$(Get-Date -Format o) | WARN: WindowsTerminal process not found" | Out-File -Append $logFile
}

# Delegate to WSL-side helper for cross-session tmux switching
$result = wsl.exe bash ~/.local/bin/tmux-jump.sh $target 2>&1
"$(Get-Date -Format o) | wsl tmux result: $result" | Out-File -Append $logFile

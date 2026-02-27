# wsl-claude-notifier

> Windows native toast notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) running in WSL2 + tmux.

![Toast notification example](assets/demo.png)

## Why?

Claude Code in WSL2 has no built-in way to notify you on Windows when a task finishes or needs input. You end up constantly alt-tabbing back to check. Worse, if you run multiple Claude sessions across tmux windows, there's no way to know *which one* needs attention — let alone jump straight to it.

This tool solves all of that:

- **Windows native toast** — real Win11 notifications when Claude Code stops or needs input, no polling
- **Tmux-aware** — title shows `[session:window]` so you instantly know which session finished
- **One-click jump** — click "Jump" on the toast to activate Windows Terminal and switch directly to the right tmux window *and pane*
- **Claude icon** — notifications are visually distinct with the Claude logo
- **Zero config** — one script installs everything: BurntToast, scripts, protocol handler, Claude Code hooks

## Tested Environment

- Windows 11 + Windows Terminal
- WSL2 (Ubuntu)
- tmux

## Quick Install

```bash
git clone <repo-url>
cd wsl-claude-notifier
bash install.sh
```

The installer handles everything:
1. Install [BurntToast](https://github.com/Windos/BurntToast) PowerShell module (if missing)
2. Deploy notification scripts to `~/.local/bin/`
3. Deploy protocol handler + icon to `C:\Users\<YOU>\.wsl-claude-notifier\`
4. Register `tmux-jump://` custom protocol
5. Add hooks to `~/.claude/settings.json`

## Prerequisites

- WSL2 with `jq` installed (`sudo apt install jq`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- tmux (recommended, works without it but no Jump button)
- Windows Terminal

<details>
<summary><h2>Manual Install</h2></summary>

### Step 1: Install BurntToast

```bash
powershell.exe -NoProfile -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser"
```

### Step 2: Deploy scripts

```bash
cp wsl-tmux-notify.sh tmux-jump.sh ~/.local/bin/
chmod +x ~/.local/bin/wsl-tmux-notify.sh ~/.local/bin/tmux-jump.sh
```

### Step 3: Deploy Windows-side files

```bash
WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
mkdir -p "/mnt/c/Users/${WIN_USER}/.wsl-claude-notifier"
cp tmux-jump.ps1 assets/icon.png "/mnt/c/Users/${WIN_USER}/.wsl-claude-notifier/"
```

### Step 4: Register protocol handler

```bash
# Replace <USER> with your Windows username
powershell.exe -NoProfile -Command @'
$proto = "tmux-jump"
$handler = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\<USER>\.wsl-claude-notifier\tmux-jump.ps1" "%1"'
New-Item -Path "HKCU:\Software\Classes\$proto" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name "(Default)" -Value "URL:tmux-jump Protocol"
New-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name "URL Protocol" -Value "" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Name "(Default)" -Value $handler
'@
```

### Step 5: Configure Claude Code hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.local/bin/wsl-tmux-notify.sh" }]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.local/bin/wsl-tmux-notify.sh" }]
      }
    ]
  }
}
```

</details>

## How It Works

```
Claude Code hook event (Stop / Notification)
  │  stdin: JSON with event type, message, cwd
  ▼
wsl-tmux-notify.sh
  ├─ Parses event, reads tmux session:window:pane
  ├─ Builds BurntToast command with Jump button + icon
  └─ PowerShell -EncodedCommand (UTF-16LE) ──► Windows toast notification
                                                        │
                                              Click "Jump" button
                                                        │
                                                        ▼
                                              tmux-jump:// protocol
                                                        │
                                                        ▼
                                              tmux-jump.ps1
                                                ├─ SetForegroundWindow() → activate Windows Terminal
                                                └─ wsl.exe tmux-jump.sh → switch tmux window + pane
```

## Uninstall

```bash
bash uninstall.sh
```

Removes all deployed files, registry entries, and Claude Code hooks.

## Troubleshooting

**No toast appears?**
- Verify BurntToast: `powershell.exe -NoProfile -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Test'"`
- Check Windows notification settings (Settings > System > Notifications)
- Ensure `jq` is installed: `which jq`

**Jump button doesn't switch window?**
- Test protocol: `powershell.exe -Command "Start-Process 'tmux-jump://main:0.0'"`
- Check handler exists: `ls /mnt/c/Users/*/.wsl-claude-notifier/tmux-jump.ps1`

**No Jump button on toast?**
- Jump button only appears when Claude Code runs inside tmux (`echo $TMUX` should have output)

---

## 中文说明

在 WSL2 + tmux 环境下，为 Claude Code 提供 Windows 原生 toast 通知。

**痛点：** WSL2 没有原生的 Windows 通知机制，多个 tmux 会话更难追踪哪个 Claude 完成了任务。

**功能：**
- Claude Code 完成任务或需要输入时弹出 Windows toast 通知
- 通知标题显示 `[session:window]` 以区分多个 tmux 会话
- 点击 "Jump" 按钮自动激活 Windows Terminal 并切换到对应 tmux 窗口和 pane
- 通知显示 Claude 图标

**安装：** `git clone` 后运行 `bash install.sh` 即可一键完成。

**卸载：** 运行 `bash uninstall.sh`。

---

## License

[MIT](LICENSE)

Icon from [lobe-icons](https://github.com/lobehub/lobe-icons) (MIT License).

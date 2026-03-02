# wsl-tmux-notifier

> 为 WSL2 + tmux 环境下的 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 和 [Codex CLI](https://github.com/openai/codex) 提供 Windows 原生 toast 通知。

[English](README.md)

## 痛点

WSL2 没有原生的 Windows 通知机制。Claude Code / Codex CLI 完成任务或需要输入时，你只能反复切回终端查看。如果同时在多个 tmux 窗口运行 AI agent，更难追踪哪个会话需要关注。

本工具解决以上所有问题：

- **Windows 原生通知** — AI agent 停止或需要输入时弹出 Win11 toast 通知
- **多工具支持** — 同时支持 Claude Code（hooks）和 Codex CLI（notify）
- **Tmux 感知** — 通知标题显示 `[session:window]`，一眼识别是哪个会话
- **一键跳转** — 点击通知上的 "Jump" 按钮，自动激活 Windows Terminal 并切换到对应 tmux 窗口 _（pane 级跳转开发中）_
- **工具图标区分** — Claude 和 Codex 通知支持各自图标，视觉辨识更清晰
- **零配置** — 一个脚本完成所有安装：BurntToast、脚本部署、协议注册、工具配置

## 测试环境

- Windows 11 + Windows Terminal
- WSL2 (Ubuntu)
- tmux

## 安装

按需安装，可以装一个或两个都装：

```bash
git clone <repo-url>
cd wsl-tmux-notifier

# Claude Code 用户
bash install-claude.sh

# Codex CLI 用户
bash install-codex.sh
```

### 各安装脚本做了什么

**共享步骤**（两个安装脚本都会处理，已完成的自动跳过）：
1. 安装 [BurntToast](https://github.com/Windos/BurntToast) PowerShell 模块
2. 部署通知 + 跳转脚本到 `~/.local/bin/`
3. 部署协议处理器 + 图标到 `C:\Users\<用户名>\.wsl-tmux-notifier\`（`icon.png` + `codex-icon.png`）
4. 注册 `tmux-jump://` 自定义协议

升级说明：旧版本使用 `.wsl-claude-notifier`；重装后可手动删除该旧目录。

**Claude Code**（步骤 5）：在 `~/.claude/settings.json` 中配置 hooks

**Codex CLI**（步骤 5）：在 `~/.codex/config.toml` 中配置 `notify`

## 前置依赖

- WSL2，已安装 `jq`（`sudo apt install jq`）
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 和/或 [Codex CLI](https://github.com/openai/codex)
- tmux（推荐，没有 tmux 也能用但无 Jump 按钮）
- Windows Terminal

## 卸载

```bash
# 移除 Claude Code 组件
bash uninstall-claude.sh

# 移除 Codex CLI 组件
bash uninstall-codex.sh
```

移除所有部署的文件、注册表项和工具配置。

## 故障排查

**通知不弹出？**
- 测试 Claude Code 通知：
  ```bash
  echo '{"hook_event_name":"Stop","cwd":"/tmp","last_assistant_message":"测试消息"}' | ~/.local/bin/wsl-tmux-notify.sh
  ```
- 测试 Codex CLI 通知：
  ```bash
  ~/.local/bin/wsl-codex-notify.sh '{"type":"agent-turn-complete","cwd":"/tmp","last-assistant-message":"测试消息"}'
  ```
- 确认 `~/.codex/config.toml` 中 `notify` 位于顶层（在任何 `[section]` 表之前）：
  ```toml
  notify = ["~/.local/bin/wsl-codex-notify.sh"]
  ```
- 校验 Codex 配置是否可解析：`codex --version`（不应出现 `config.toml` 类型错误）
- 验证 BurntToast：`powershell.exe -NoProfile -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Test'"`
- 检查 Codex 图标文件：`ls /mnt/c/Users/*/.wsl-tmux-notifier/codex-icon.png`
- 检查 Windows 通知设置（设置 > 系统 > 通知）
- 确认 `jq` 已安装：`which jq`

**Jump 按钮没有跳转？**
- 查看当前 tmux 位置：`tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'`
- 直接测试跳转：`bash ~/.local/bin/tmux-jump.sh <session>:<window>.<pane>`
- 测试协议处理器：`powershell.exe -Command "Start-Process 'tmux-jump://<session>:<window>.<pane>'"`
- 检查处理器是否存在：`ls /mnt/c/Users/*/.wsl-tmux-notifier/tmux-jump.ps1`
- 查看协议日志：`cat /mnt/c/Users/*/.wsl-tmux-notifier/tmux-jump.log`

**通知没有 Jump 按钮？**
- Jump 按钮仅在 tmux 环境内出现（`echo $TMUX` 应有输出）

## License

[MIT](LICENSE)

图标来自 [lobe-icons](https://github.com/lobehub/lobe-icons)（MIT License）。

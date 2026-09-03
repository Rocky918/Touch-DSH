# Touch DSH 0.1.0-beta.1

首个公开测试版。请先阅读仓库首页的前置条件与安装说明。

## 下载哪个版本？

- **有 Touch Bar：** `Touch-DSH-TouchBar-0.1.0-beta.1.zip`
- **无 Touch Bar：** `Touch-DSH-Menu-0.1.0-beta.1.zip`

两个文件都是 Universal 2，同时支持 Intel 和 Apple 芯片。请勿同时运行两个版本。

## 前置条件

- macOS 13+
- 已安装 DeepSeek Harness，且 `dsh --version` 可运行
- 当前完整验证基线：DeepSeek Harness `0.1.1-rc.2`
- Touch Bar 版需要实体 Touch Bar

## 主要功能

- 菜单栏和 Touch Bar 显示 DSH 状态
- 一键启动 DSH 和打开对话
- 识别常见 Homebrew、NVM、Volta、pnpm、asdf 与本地安装路径
- 经进程身份复核后安全退出 DSH
- 可选的开机自动启动组件
- 本地日志、权限限制与 5 MB 轮转

## 安装提醒

当前测试版采用临时签名、尚未经过 Apple 公证。首次运行请按住 Control 点击应用并选择“打开”，或在“系统设置 → 隐私与安全性”中确认。

Touch Bar 版使用 macOS 未公开接口，系统更新可能影响其功能。遇到问题请使用仓库中的 Bug 模板，并先移除日志和截图中的隐私信息。

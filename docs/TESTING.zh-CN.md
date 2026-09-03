# Touch DSH 测试矩阵

每一轮公开测试至少覆盖以下组合：

| 版本 | 芯片 | Touch Bar | 当前状态 |
| --- | --- | --- | --- |
| Touch DSH | Intel | 有 | 本机验证 |
| Touch DSH | Apple 芯片 | 有 | 需要外部设备验证 |
| Touch DSH Menu | Intel | 无/不使用 | 需要验证 |
| Touch DSH Menu | Apple 芯片 | 无 | 需要外部设备验证 |

## 基础检查

- 首次启动与菜单栏图标
- DSH 未启动、空闲、工作、等待确认、异常状态
- 启动 DSH、打开对话、安全退出及强制退出保护
- 登录时启动开关
- 日志权限与 5 MB 轮转
- 媒体播放期间的 Touch Bar 胶囊可见性
- 睡眠、唤醒及网络恢复

提交问题前，请记录应用版本、版本类型、Mac 型号、芯片、macOS 与 `dsh --version`，并删除日志中的隐私内容。

# Touch DSH

[English](README.en.md) | 简体中文

> **非官方社区项目。** Touch DSH 与 DeepSeek 不存在隶属、合作或官方背书关系。

![Touch DSH 功能总览](docs/media/Touch-DSH-Overview.png)

## 为什么需要 Touch DSH？

DeepSeek Harness（`dsh`）主要从终端启动。关闭浏览器并不等于停止 DSH，后台服务可能仍在运行；重新使用时还要回到终端输入命令，也很难一眼判断模型正在工作、等待确认，还是已经异常中断。

Touch DSH 把这些高频操作放到 macOS 菜单栏和 Touch Bar：不用保留终端窗口，就能查看状态、启动 DSH、打开对话，并在确认后彻底停止后台服务。

它主要解决四个问题：

- **启动麻烦：** 不再需要每次打开终端输入 `dsh web`。
- **状态不透明：** Logo 颜色直接反映空闲、工作、等待确认和异常状态。
- **网页与服务容易混淆：** 关闭网页后仍能看出 DSH 是否留在后台。
- **退出不彻底：** 提供经过进程身份校验的安全退出，避免误关其他 Node 程序。

## 先选择版本

| 你的 Mac | 下载文件 | 功能 |
| --- | --- | --- |
| **配备 Touch Bar** | `Touch-DSH-TouchBar-0.1.0-beta.1.zip` | Touch Bar 控件 + 菜单栏备用入口 |
| **没有 Touch Bar** | `Touch-DSH-Menu-0.1.0-beta.1.zip` | 仅菜单栏，不包含 Touch Bar 私有接口 |

两个安装包都是 **Universal 2**，一个文件同时支持 Intel（`x86_64`）和 Apple 芯片（`arm64`），不需要再区分 M1/M2/M3/M4 与 Intel。请勿同时运行两个版本。

前往 [Releases 下载](https://github.com/Rocky918/Touch-DSH/releases/latest)。

## 前置条件

安装 Touch DSH 前，请确认：

1. macOS 13 或更高版本。
2. 已安装 DeepSeek Harness，并能在终端执行 `dsh --version`。
3. 当前唯一完整验证的兼容基线是 **DeepSeek Harness `0.1.1-rc.2`**，建议测试阶段使用这个版本。
4. 使用 Touch Bar 版时，Mac 必须配备实体 Touch Bar。

Touch DSH 不包含、也不会替你安装 DeepSeek Harness。DSH 仍处于开发预览阶段，后续版本可能带来不兼容变更。

## 安装

1. 在 [Releases](https://github.com/Rocky918/Touch-DSH/releases/latest) 下载适合设备的 ZIP。
2. 双击 ZIP 解压。
3. 将 `Touch DSH.app` 或 `Touch DSH Menu.app` 拖入“应用程序”文件夹。
4. 当前测试版采用临时签名、尚未经过 Apple 公证。首次打开时，请按住 Control 点击应用并选择“打开”；如果仍被拦截，到“系统设置 → 隐私与安全性”中确认打开。
5. 启动后，在屏幕顶部菜单栏中找到鲸鱼图标。Touch Bar 版还会在 Control Strip 中显示鲸鱼胶囊。

请只从本仓库的 Release 页面下载安装包，并可使用同一版本附件中的 `SHA256SUMS.txt` 校验文件。

## 使用

### 启动 DSH

- 菜单栏：点击鲸鱼图标，选择“启动 DSH”。
- Touch Bar：点击鲸鱼胶囊展开，然后点击“启动 DSH”。

启动成功后，Touch DSH 会连接本机 `http://127.0.0.1:3080/`。它会自动识别常见 Homebrew、NVM、Volta、pnpm、asdf 和本地安装位置中的 `dsh`。

### 打开对话

DSH 在线后，点击“打开对话”即可在默认浏览器打开对话页面。重复点击不会创建大量重复页面。

### 彻底退出 DSH

点击“安全退出 DSH…”或 Touch Bar 上的“退出 DSH”。Touch DSH 会先核验 3080 端口上的进程、当前用户、启动时间和命令，再请求确认并停止对应 DSH 服务。

### 开机自动启动

勾选“开机自动启动”后，登录 macOS 时会自动运行 **Touch DSH 组件**。它不会自动启动 DSH 服务或打开网页；DSH 仍由你手动启动。

### 状态颜色

- 默认色 Logo：DSH 未启动
- 蓝色 Logo：后台空闲
- 绿色 Logo：正在工作
- 黄色 Logo 闪烁：等待授权、确认或回答选择
- 红色 Logo 闪烁：异常、中断或阻塞
- 绿色边框：DSH 服务在线

## 功能演示

[观看 20 秒 Touch DSH 功能演示](https://github.com/Rocky918/Touch-DSH/releases/download/v0.1.0-beta.1/Touch-DSH-Demo.mp4)

## 测试版说明

- `0.1.0-beta.1` 是首个公开测试版，建议先由不同型号 Mac 用户验证。
- Touch Bar 版使用 macOS 未公开接口，不能提交 Mac App Store，并可能受到未来系统更新影响。
- 当前没有 Developer ID 公证；普通用户需要按上面的首次打开步骤操作。
- 如果出现问题，请在 Issues 中选择 Bug 模板，并先删除日志中的用户名、路径、提示词、凭证和其他隐私内容。

## 安全与隐私

- 仅访问本机 `127.0.0.1:3080` 上的 DSH Web 服务。
- 不收集遥测，不读取或保存模型 API Key。
- 停止 DSH 前会重复验证进程身份，避免 PID 被替换后误杀其他程序。
- 日志位于 `~/Library/Logs/Touch DSH/dsh-web.log`，仅当前用户可读写；达到 5 MB 后保留一份轮转备份。

详细说明见 [SECURITY.md](SECURITY.md)。测试矩阵见 [docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md)。

## 卸载

1. 在菜单中关闭“开机自动启动”。
2. 选择“退出 Touch DSH”。
3. 从“应用程序”文件夹删除 App。
4. 如不再需要日志，可手动删除 `~/Library/Logs/Touch DSH/`。

卸载 Touch DSH 不会卸载 DeepSeek Harness。

## 从源码构建

需要 Xcode 15 或更高版本及 Swift 5.9 工具链。项目已在 Intel Mac、Xcode 26.5 上验证。

```sh
swift test
zsh Scripts/package.sh
```

脚本会分别构建 Intel 和 Apple 芯片版本，再合并为两个 Universal 2 应用。输出位于 `dist/`。设置 `SIGN_IDENTITY` 可以改用 Developer ID 签名。

## 开源许可与品牌

代码采用 [MIT License](LICENSE)。DeepSeek、DeepSeek Harness 名称及相关品牌素材属于其权利人，品牌素材不因本仓库的 MIT 许可而获得额外授权。使用时请遵循 [DeepSeek Harness 品牌素材使用规范](https://github.com/deepseek-ai/deepseek-harness/blob/master/BRAND_GUIDELINES.zh.md)。

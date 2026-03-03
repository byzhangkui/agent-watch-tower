# Progress Record

## [2026-03-03] Swift 并发及 Actor 隔离编译错误修复

- **遇到了什么问题：**
  在执行 `make install` 编译应用时，遇到了与 Swift 6 `MainActor` 隔离相关的编译错误和警告。
  
- **如何解决的：**
  为主执行器隔离的属性和方法添加了正确的 `@MainActor` 标注，对被废弃在 `deinit` 中清理的 observer 使用了 `@ObservationIgnored nonisolated(unsafe)` 进行标注。

- **Git Commit ID:**
  32b5a09b319c18d4feb820940247b60cf7725707

## [2026-03-03] UI 缺失 Settings 按钮导致无法安装 Hooks

- **遇到了什么问题：**
  Agent Watch Tower 的主面板上缺少了 “设置 (Settings)” 图标入口。

- **如何解决的：**
  修改 `Sources/Views/Panel/PanelToolbarView.swift` 文件，在 Toolbar 中补上了带有 `gearshape.fill` 样式的设置图标按钮。

- **Git Commit ID:**
  5cd63c64c7674258cdb8b5de9f03ce3761cc2e88

## [2026-03-03] 独立应用无退出入口导致无法关闭

- **遇到了什么问题：**
  Agent Watch Tower 默认隐藏在 Dock 中，如果没有右键菜单或面板内对应的退出按钮，用户打开之后无法正常退出应用进程。

- **如何解决的：**
  在 `PanelToolbarView` 视图的设置按钮旁，添加了一个调用了 `NSApp.terminate(nil)` 的 `power`（电源开关）按钮。

- **Git Commit ID:**
  0ce25a97c238f2c594162a03ede0548b89de7ea6

## [2026-03-03] SwiftUI 的 Settings 窗口在 Accessory 模式下无法打开

- **遇到了什么问题：**
  纯 Accessory 模式应用由于缺少主菜单栏，无法正确响应和路由默认的 `showSettingsWindow:` Action。且在手动创建 Window 后，存在用户关闭窗口再点击无效的情况，因为之前的 Window 对象被强引用但 `isVisible` 已经变为 `false`。

- **如何解决的：**
  在 `AppDelegate` 中手动创建和管理 `NSWindow` 实例，将 `SettingsView` 通过 `NSHostingView` 挂载进去，调用自定义的方法来唤出设置窗口并前置。当复用之前创建的窗口前，额外检查其 `.isVisible` 属性，如果不处于显示状态则重新触发新建和渲染。对于其他调用途径可能失败的情况，也加上了对全局环境发送 Action 机制的兜底。

- **Git Commit ID:**
  58a6b427ae47b25439fd68a450c919bc0ed9fbd1

## [2026-03-03] 接收 Claude Code JSON 数据解析失败

- **遇到了什么问题：**
  即使正确安装了 HTTP 钩子，Claude Code 启动时发送的 `SessionStart` 事件也没有在面板上显示。追踪发现是因为 Claude Code 在某些事件中去除了 `cwd` (工作目录) 字段，导致后端的 `JSONDecoder` 因为严格验证失败而直接丢弃了整条事件数据。

- **如何解决的：**
  在 `HookPayload.swift` 中，将 `cwd` 字段改为可选类型（`String?`），同时在对应的解析 Adapter 中提供 `"Unknown Directory"` 作为后备（Fallback）值；为了方便后续追踪，还为 `EventRouter.swift` 补充了详细的错误打印。

- **以后如何避免：**
  在对接不受自己控制的第三方客户端（如 Claude Code）所发送的 Webhook 负载时，应当**默认将所有非绝对核心主键的属性声明为可选值（Optional）**，以防版本升级或其他原因造成字段缺失，从而破坏整个服务的稳定性。

- **Git Commit ID:**
  af594a5bbfbb8e9acaf8609beeb58087d110b038

## [2026-03-03] 点击设置按钮无反应

- **遇到了什么问题：**
  在 `.accessory` 模式的浮动面板/Popover 中点击设置按钮（齿轮图标）毫无反应，设置窗口未能弹出。根本原因有两点：1) `NSApp.activate(ignoringOtherApps:)` 在 `makeKeyAndOrderFront` 之后调用，当 app 处于非激活状态时窗口无法正确前置；2) Popover 的 `.transient` 行为与 `NSApp.activate` 调用产生竞争，导致窗口被遮盖或无法获取焦点。

- **如何解决的：**
  在 `AppDelegate.showSettings()` 中做了两处调整：
  1. 先检查并关闭 Popover（`popoverManager.close()`），避免 transient 行为干扰；
  2. 将 `NSApp.activate(ignoringOtherApps: true)` 提前到 `window.makeKeyAndOrderFront(nil)` 之前调用，确保 app 先激活，再前置窗口。

- **以后如何避免：**
  在 `.accessory` 模式应用中展示窗口时，务必先激活 app（`NSApp.activate`），再调用 `makeKeyAndOrderFront`。如果窗口在 Popover 内触发，要先关闭 Popover，再展示新窗口，避免窗口层级冲突。

- **Git Commit ID:** 2865e53

## [2026-03-03] 工具调用事件 (PreToolUse/PostToolUse) 丢失，列表为空

- **遇到了什么问题：**
  在 Agent Watch Tower 的卡片详情页中，"RECENT EVENTS"（最近事件）列表显示了一些不包含工具信息的空行。通过排查用户项目下的 `.claude/projects/xxx.jsonl` 日志，发现内部系统报出了 `"JSON validation failed: HTTP hook must return JSON, but got non-JSON response body: ok"` 的错误。原来是因为内嵌 HTTP Server 在处理 Hook 时只返回了纯文本 `"ok"`，导致 Claude Code 认为 Hook 响应失败，从而阻断了后续如 `PreToolUse` 和 `PostToolUse` 的正式发送。

- **如何解决的：**
  修改了 `Sources/Server/EventServer.swift` 文件中对于所有 `/events/` 系列接口的返回类型。从单纯的 `.text("ok")` 变更为了返回合法的空 JSON 对象 `.json([String: String]())` (即 `{}`)。这样既返回了 200 状态码，又通过了 Claude 的 JSON 验证。

- **以后如何避免：**
  当实现 Webhook Server 接收第三方请求时，务必查阅和严格遵循第三方对 Response 格式的要求。尤其是对那些期待 JSON 解析的调用源，绝不应随意返回纯文本的 "ok" 或者空字符。

- **Git Commit ID:**
  c4b9cee3fbb4fe84f59543cfd5f1f2f092899c81

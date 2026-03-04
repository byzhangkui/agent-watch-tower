# Progress Record

## [2026-03-04] Session 自动消失 / 列表顺序不稳定

- **遇到了什么问题：**
  1. 用户发现 Session 列表中的项目会自动消失。
  2. Session 列表的顺序在确定后会不断变化（新事件到来后某个 session 会跳到顶部）。

- **如何解决的：**
  1. **Session 消失**：`SessionListViewModel.reload()` 中原来写的是 `sessions = (try? sessionStore.todaySessions()) ?? []`，当数据库读取失败时会将列表置空。改为 `if let fetched = try? sessionStore.todaySessions() { sessions = fetched }`，DB 出错时保留已有数据，避免列表闪烁/清空。
  2. **顺序不稳定**：`SessionStore.todaySessions()` 原来按 `updated_at DESC` 排序，而每次 hook 事件到来都会更新 `updated_at`，导致列表顺序随事件流不断变化。改为按 `started_at DESC` 排序，Session 创建后顺序固定不变。

- **以后如何避免：**
  - 列表数据源发生错误时，**应保留已有数据而非替换为空**，避免 UI 闪烁。
  - 列表排序字段应选择**创建时不再变化的字段**（如 `started_at`），而不是频繁更新的字段（如 `updated_at`），否则列表顺序会随业务事件不断跳动。

- **Git Commit ID:** 9a1f4df

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

## [2026-03-04] Session 出现慢 / 状态更新有延迟

- **遇到了什么问题：**
  1. 用户在 Claude Code 中输入内容后，session 卡片要过好一会才出现在列表中。
  2. Session 状态（如 running → completed）切换也有明显延迟；工具执行完毕后 `currentAction` 还残留着上一个工具的文字。

- **如何解决的：**
  1. **新增 `UserPromptSubmit` hook**：该 hook 在用户按下 Enter 时立刻触发（早于任何工具调用），在 `HookInstaller` 和 `EventServer` 中注册此路由，`ClaudeCodeAdapter` 处理后立即创建 session，做到近实时出现。
  2. **周期性兜底刷新**：在 `SessionListViewModel` 中加入 2 秒 `Timer`，即使某个 hook 通知被漏掉，UI 也会在 2 秒内同步最新状态。
  3. **`PostToolUse` 后清空 `currentAction`**：工具完成后将 `currentAction = nil`，避免 Claude 在思考阶段显示上一个工具的残留文本。
  4. **Duration 计数器实时更新**：`SessionCardView` 中用 `TimelineView(.periodic(from:by:1))` 替代静态 `durationFormatted`，活跃 session 的时长每秒刷新一次。

- **以后如何避免：**
  - 依赖 hook 推送做唯一 UI 更新来源是脆弱的，**必须搭配周期性轮询作为兜底**。
  - 新增 hook 事件时，同步在 `HookInstaller`（注册）、`EventServer`（路由）、`ClaudeCodeAdapter`（处理）三处更新，缺一不可。注意：新增 hook 后用户需重新点击「Install Hooks」才能生效。

- **Git Commit ID:** 387981a, 46637ba

## [2026-03-04] 点击设置按钮无反应（根本原因修复）

- **遇到了什么问题：**
  在 SwiftUI App 生命周期（`@main struct ... : App`）下，`NSApp.delegate as? AppDelegate` 这个类型转换会失败（SwiftUI 内部将 delegate 包裹在自己的代理对象中），导致 `openSettings()` 的两个分支都无法正确执行：主路径转型失败，回退路径 `sendAction("showSettingsWindow:")` 在 `.accessory` 模式下也无响应。结果就是点击设置按钮完全没有任何反应。

- **如何解决的：**
  将 `showSettings` 从"在视图内部通过 `NSApp.delegate` 查找 AppDelegate"改为**直接以闭包形式注入** `PanelRootView`（新增 `onShowSettings: () -> Void` 参数），在 `AppDelegate` 创建 `PanelRootView` 时传入 `{ [weak self] in self?.showSettings() }`。彻底绕过 AppKit/SwiftUI 边界的 delegate 转型问题。

- **以后如何避免：**
  在 SwiftUI App 生命周期中，**不要依赖 `NSApp.delegate as? MyAppDelegate`**，这个转型在 SwiftUI 生命周期下不可靠。需要从 AppKit 层调用功能时，应该通过闭包注入或 NotificationCenter 而非尝试反向查找 delegate。

- **Git Commit ID:** de3e3d2

## [2026-03-04] Event 显示空白 / Title 变高 / PIN 体验差 / 暗黑模式图标 / App 图标

- **遇到了什么问题：**
  1. 详情页 RECENT EVENTS 中 `SessionStart`/`Stop`/`Notification` 等生命周期事件只显示图标，没有文字。
  2. 进入详情页后 title 区域变高（NavigationStack 导航栏与自定义 Back 按钮叠加）。
  3. PIN 切换时有"新建窗口"感：`FloatingPanelController.show()` 每次重建 `NSPanel`。
  4. 状态栏图标在暗黑模式下显示异常（未设置 `isTemplate`）。
  5. 应用没有 App 图标。

- **如何解决的：**
  1. `ClaudeCodeAdapter.describeAction()` 新增对生命周期事件的文字描述；`AgentEvent.toolIcon` 按 `eventType` 返回对应图标。
  2. 去掉 `SessionDetailView` 中的 `.navigationTitle()`，改用 `.navigationBarBackButtonHidden(true)` + 自定义 Back 按钮行。
  3. `FloatingPanelController` 新增 `hide()` 方法（`orderOut`，不销毁），`show()` 复用已有 panel；`PinStateManager` 取消 pin 时调 `hide()` 而非 `close()`，重新 pin 时 panel 瞬间复现，无重建开销。
  4. 对所有 SF Symbol 图片显式设置 `isTemplate = true`；idle 状态清除 `contentTintColor`。
  5. 用 Python/Pillow 生成深色调雷达塔主题图标，`iconutil` 打包为 `.icns`，写入 `Info.plist`。

- **以后如何避免：**
  - macOS `NavigationStack` 在 panel/popover 中不显示标准返回按钮，**必须手动添加**。
  - NSPanel 应预创建并复用，切换显示/隐藏用 `orderFrontRegardless`/`orderOut`，避免反复重建导致"新窗口"感。
  - SF Symbol 用于状态栏时**必须设置 `isTemplate = true`**，否则暗黑模式下颜色不自适应。

- **Git Commit ID:** 382435b

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

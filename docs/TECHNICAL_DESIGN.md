# Agent Watch Tower - 技术方案设计

## 1. 工程结构

```
AgentWatchTower/
├── AgentWatchTower.xcodeproj
├── Package.swift                          # SPM 依赖声明
│
├── Sources/
│   ├── App/
│   │   ├── AgentWatchTowerApp.swift       # @main 入口，Menu Bar 生命周期
│   │   └── AppDelegate.swift              # NSApplicationDelegate，管理窗口
│   │
│   ├── Window/                            # 窗口管理层
│   │   ├── StatusBarController.swift      # NSStatusItem + 图标动画
│   │   ├── PopoverManager.swift           # NSPopover 管理
│   │   ├── FloatingPanelController.swift  # NSPanel always-on-top 悬浮窗
│   │   └── PinStateManager.swift          # Popover ↔ FloatingPanel 切换
│   │
│   ├── Views/                             # SwiftUI 视图
│   │   ├── Panel/
│   │   │   ├── PanelRootView.swift        # 面板根视图（NavigationStack）
│   │   │   ├── SessionListView.swift      # 会话列表（主页）
│   │   │   ├── SessionCardView.swift      # 单个会话卡片
│   │   │   ├── DailySummaryView.swift     # 今日汇总条
│   │   │   └── PanelToolbarView.swift     # 标题栏（Pin 按钮等）
│   │   ├── Detail/
│   │   │   ├── SessionDetailView.swift    # 会话详情页
│   │   │   ├── TaskProgressView.swift     # 任务进度列表
│   │   │   ├── EventTimelineView.swift    # 事件时间线
│   │   │   ├── EventRowView.swift         # 单条事件（折叠/展开）
│   │   │   └── ToolUsageChartView.swift   # 工具调用分布
│   │   ├── Settings/
│   │   │   └── SettingsView.swift         # 设置窗口
│   │   └── Components/
│   │       ├── StatusIndicator.swift      # 状态指示灯组件
│   │       ├── ProgressBarView.swift      # 任务进度条
│   │       └── TokenBadgeView.swift       # Token 用量标签
│   │
│   ├── ViewModels/                        # MVVM ViewModel
│   │   ├── SessionListViewModel.swift     # 会话列表状态
│   │   ├── SessionDetailViewModel.swift   # 会话详情状态
│   │   └── SettingsViewModel.swift        # 设置状态
│   │
│   ├── Models/                            # 数据模型
│   │   ├── AgentSession.swift
│   │   ├── AgentEvent.swift
│   │   ├── TokenUsage.swift
│   │   └── Enums.swift                    # AgentType, SessionStatus, EventType
│   │
│   ├── Server/                            # 内嵌 HTTP 服务
│   │   ├── EventServer.swift              # HTTP 服务器主体
│   │   ├── EventRouter.swift              # 路由定义
│   │   └── HookPayload.swift             # Hook stdin JSON 解析
│   │
│   ├── Adapters/                          # Agent 适配层
│   │   ├── AgentAdapter.swift             # 协议定义
│   │   ├── ClaudeCodeAdapter.swift        # Claude Code 事件适配
│   │   └── GeminiAdapter.swift            # Gemini 事件适配（Phase 2 占位）
│   │
│   ├── Storage/                           # 持久化
│   │   ├── Database.swift                 # GRDB 数据库初始化 + 迁移
│   │   ├── SessionStore.swift             # Session CRUD
│   │   └── EventStore.swift               # Event CRUD
│   │
│   └── Utilities/
│       ├── HookInstaller.swift            # 自动写入 Claude Code Hook 配置
│       ├── CostCalculator.swift           # Token → 费用换算
│       └── Constants.swift                # 端口号、路径等常量
│
├── Resources/
│   ├── Assets.xcassets/                   # 图标资源
│   └── AgentWatchTower.entitlements       # 沙盒 / 网络权限
│
└── Tests/
    ├── ServerTests/
    ├── AdapterTests/
    └── StorageTests/
```

---

## 2. 模块架构

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│                                                             │
│   StatusBarController ←→ PopoverManager ←→ FloatingPanel    │
│              │                  │                            │
│              └──────┬───────────┘                            │
│                     │ SwiftUI Views                          │
│          ┌──────────┴──────────┐                             │
│          │   PanelRootView     │                             │
│          │   SessionListView   │                             │
│          │   SessionDetailView │                             │
│          └──────────┬──────────┘                             │
├─────────────────────┼───────────────────────────────────────┤
│                ViewModel Layer                               │
│                     │                                        │
│          ┌──────────┴──────────┐                             │
│          │ SessionListViewModel│ @Observable                 │
│          │ SessionDetailVM     │                             │
│          └──────────┬──────────┘                             │
│                     │                                        │
├─────────────────────┼───────────────────────────────────────┤
│                Service Layer                                 │
│                     │                                        │
│    ┌────────────────┼──────────────────┐                     │
│    │                │                  │                     │
│    ▼                ▼                  ▼                     │
│ EventServer    AgentAdapters     Storage(GRDB)               │
│ (HTTP :19280)  (Protocol)        (SQLite)                    │
│    │                │                  ▲                     │
│    │    ┌───────────┤                  │                     │
│    │    │           │                  │                     │
│    ▼    ▼           ▼                  │                     │
│  ClaudeCode     Gemini(P2)    ─────────┘                     │
│  Adapter        Adapter                                      │
└─────────────────────────────────────────────────────────────┘
```

**数据流向：**
```
Claude Code Hook 触发
    → curl POST JSON to localhost:19280
        → EventServer 接收
            → EventRouter 分发
                → ClaudeCodeAdapter 转换为统一模型
                    → EventStore 写入 SQLite
                    → SessionStore 更新会话状态
                        → ViewModel 通过 @Observable 驱动 UI 刷新
```

---

## 3. 窗口管理

### 3.1 应用生命周期

应用采用 `MenuBarExtra` 模式，不显示 Dock 图标，不创建主窗口。

```swift
// AgentWatchTowerApp.swift
@main
struct AgentWatchTowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用 Settings scene 提供 ⌘, 快捷键
        Settings {
            SettingsView()
        }
    }
}
```

Menu Bar 和 Popover 由 `AppDelegate` 通过 AppKit 管理，不使用 SwiftUI 的 `MenuBarExtra`（它对 NSPanel 切换的控制不够精细）。

### 3.2 StatusBarController

```swift
// StatusBarController.swift
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var animationTimer: Timer?

    enum IconState {
        case idle          // 静态灰色图标
        case running(Int)  // 脉冲动画 + 活跃数
        case error         // 叠加红点
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        // 配置 button action → 触发 PopoverManager
    }

    func updateIcon(_ state: IconState) {
        // 根据状态切换 NSImage + 启停 Timer 动画
    }
}
```

### 3.3 Popover ↔ Floating Panel 切换

两种窗口形态共享同一个 SwiftUI View 层级，通过 `PinStateManager` 协调切换：

```swift
// PinStateManager.swift
@Observable
final class PinStateManager {
    var isPinned: Bool = false
    var lastPinnedFrame: NSRect?  // 记忆上次 Pin 位置

    private let popoverManager: PopoverManager
    private let floatingPanel: FloatingPanelController

    func togglePin() {
        isPinned.toggle()
        if isPinned {
            // 1. 关闭 Popover
            popoverManager.close()
            // 2. 在 Popover 同位置打开 FloatingPanel
            floatingPanel.show(at: lastPinnedFrame ?? defaultFrame)
        } else {
            // 1. 关闭 FloatingPanel，记忆位置
            lastPinnedFrame = floatingPanel.window?.frame
            floatingPanel.close()
            // 2. 重新打开 Popover
            popoverManager.show()
        }
    }
}
```

### 3.4 FloatingPanelController

```swift
// FloatingPanelController.swift
final class FloatingPanelController {
    private var panel: NSPanel?

    func show(at frame: NSRect) {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating                    // always-on-top
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false            // 不随失焦隐藏
        panel.becomesKeyOnlyIfNeeded = true        // 不抢焦点
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 尺寸约束
        panel.minSize = NSSize(width: 280, height: 300)
        panel.maxSize = NSSize(width: 480, height: 800)

        // 嵌入 SwiftUI
        panel.contentView = NSHostingView(rootView: PanelRootView())

        panel.orderFrontRegardless()
        self.panel = panel
    }
}
```

**关键点：**
- `nonactivatingPanel`：点击面板不会让当前编辑器失去焦点
- `becomesKeyOnlyIfNeeded`：只在需要时（如搜索框输入）才获取键盘焦点
- `canJoinAllSpaces`：在所有桌面空间可见
- `hidesOnDeactivate = false`：切换到其他应用时面板不消失

---

## 4. 内嵌 HTTP 服务器

### 4.1 选型：Swifter

选用 [Swifter](https://github.com/httpswift/swifter) 作为内嵌 HTTP 服务器：
- 纯 Swift，无外部依赖
- 单文件即可嵌入
- 支持 macOS，适合本地轻量服务

### 4.2 EventServer

```swift
// EventServer.swift
import Swifter

final class EventServer {
    private let server = HttpServer()
    private let port: UInt16 = 19280
    private let eventRouter: EventRouter

    init(eventRouter: EventRouter) {
        self.eventRouter = eventRouter
        setupRoutes()
    }

    private func setupRoutes() {
        // 接收 Hook 事件
        server.POST["/events"] = { [weak self] request in
            guard let body = try? JSONDecoder().decode(
                HookPayload.self,
                from: Data(request.body)
            ) else {
                return .badRequest(.text("Invalid JSON"))
            }
            await self?.eventRouter.handle(body)
            return .ok(.text("ok"))
        }

        // 健康检查（供 Settings 页面 Test Connection 使用）
        server.GET["/health"] = { _ in
            return .ok(.json(["status": "running"]))
        }
    }

    func start() throws {
        try server.start(port, forceIPv4: true, priority: .default)
    }

    func stop() {
        server.stop()
    }
}
```

### 4.3 HookPayload — Claude Code Hook 数据解析

Claude Code Hooks 通过 stdin 传递 JSON，Hook 脚本再通过 curl POST 转发。我们需要解析的完整 payload：

```swift
// HookPayload.swift

/// Claude Code Hook 传入的 JSON 结构
struct HookPayload: Codable {
    // ── 通用字段（所有 Hook 事件都有）──
    let sessionId: String
    let cwd: String
    let hookEventName: String          // "PreToolUse", "PostToolUse", "Notification" 等
    let transcriptPath: String?

    // ── PreToolUse / PostToolUse 字段 ──
    let toolName: String?              // "Bash", "Edit", "Read", "Write", "Grep" 等
    let toolInput: ToolInput?          // 工具的完整输入
    let toolResponse: AnyCodable?      // PostToolUse 才有，工具的完整输出
    let toolUseId: String?

    // ── SessionStart 字段 ──
    let source: String?                // "startup", "resume", "clear"
    let model: String?                 // "claude-sonnet-4-6" 等

    // ── SubagentStart / SubagentStop 字段 ──
    let agentName: String?
    let agentType: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case transcriptPath = "transcript_path"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case toolUseId = "tool_use_id"
        case source, model
        case agentName = "agent_name"
        case agentType = "agent_type"
    }
}

/// 工具输入 — 不同工具结构不同，用可选字段兼容
struct ToolInput: Codable {
    // Bash
    let command: String?
    let description: String?
    let timeout: Int?

    // Read / Write / Edit
    let filePath: String?
    let content: String?
    let oldString: String?
    let newString: String?

    // Grep / Glob
    let pattern: String?
    let path: String?
    let glob: String?

    // Agent
    let prompt: String?
    let subagentType: String?

    enum CodingKeys: String, CodingKey {
        case command, description, timeout
        case filePath = "file_path"
        case content
        case oldString = "old_string"
        case newString = "new_string"
        case pattern, path, glob
        case prompt
        case subagentType = "subagent_type"
    }
}
```

---

## 5. Claude Code Hooks 配置

### 5.1 Hook 安装脚本

应用提供一键安装功能（Settings → Claude Code → Install Hooks），自动向 `~/.claude/settings.json` 注入 Hook 配置。

采用 **HTTP Hook 类型**（而非 command + curl），更简洁高效：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/pre-tool-use",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/post-tool-use",
            "timeout": 5
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/notification",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/session-start",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/stop",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/subagent-start",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:19280/events/subagent-stop",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### 5.2 Hook 安装器实现

```swift
// HookInstaller.swift
struct HookInstaller {
    static let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    static let hookRoutes: [(event: String, path: String)] = [
        ("PreToolUse",    "/events/pre-tool-use"),
        ("PostToolUse",   "/events/post-tool-use"),
        ("Notification",  "/events/notification"),
        ("SessionStart",  "/events/session-start"),
        ("Stop",          "/events/stop"),
        ("SubagentStart", "/events/subagent-start"),
        ("SubagentStop",  "/events/subagent-stop"),
    ]

    /// 读取现有配置 → 合并 hooks → 写回
    static func install(port: UInt16 = 19280) throws {
        var settings = try readExistingSettings()

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for route in hookRoutes {
            let entry: [String: Any] = [
                "matcher": "",
                "hooks": [[
                    "type": "http",
                    "url": "http://localhost:\(port)/events/\(route.path)",
                    "timeout": 5
                ]]
            ]
            // 追加而非覆盖，保留用户已有 hooks
            var existing = hooks[route.event] as? [[String: Any]] ?? []
            // 检查是否已存在 watch-tower 的 hook，避免重复
            let alreadyInstalled = existing.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["url"] as? String)?.contains("localhost:\(port)") == true
                }
            }
            if !alreadyInstalled {
                existing.append(entry)
            }
            hooks[route.event] = existing
        }

        settings["hooks"] = hooks
        try writeSettings(settings)
    }

    /// 移除 watch-tower 相关的 hooks
    static func uninstall(port: UInt16 = 19280) throws { /* ... */ }
}
```

### 5.3 我们监听的 Hook 事件及用途

| Hook 事件 | 用途 | 对应面板元素 |
|-----------|------|-------------|
| `SessionStart` | 创建新会话记录，获取模型信息 | 会话卡片出现 |
| `PreToolUse` | 更新当前动作 "▶ Editing xxx" | 卡片动作行、状态灯变绿 |
| `PostToolUse` | 记录工具调用结果、耗时、Token | 事件时间线、工具分布图 |
| `Stop` | 标记会话完成/暂停 | 卡片状态变为 Completed |
| `Notification` | 捕获通知事件 | macOS 原生通知转发 |
| `SubagentStart` | 记录子 Agent 启动 | 事件时间线 |
| `SubagentStop` | 记录子 Agent 结束 | 事件时间线 |

---

## 6. Agent Adapter 协议

统一的适配器协议，Phase 2 扩展 Gemini 只需新增一个实现：

```swift
// AgentAdapter.swift
protocol AgentAdapter {
    /// Adapter 处理的 Agent 类型
    var agentType: AgentType { get }

    /// 将原始 Hook payload 转换为统一的 AgentEvent
    func parseEvent(from payload: HookPayload) -> AgentEvent?

    /// 从 payload 提取/更新 Session 信息
    func updateSession(from payload: HookPayload, existing: AgentSession?) -> AgentSession

    /// 从 tool_input 提取人类可读的动作描述
    func describeAction(from payload: HookPayload) -> String?
}
```

### Claude Code Adapter 实现

```swift
// ClaudeCodeAdapter.swift
struct ClaudeCodeAdapter: AgentAdapter {
    let agentType: AgentType = .claudeCode

    func describeAction(from payload: HookPayload) -> String? {
        guard let toolName = payload.toolName else { return nil }
        let input = payload.toolInput

        switch toolName {
        case "Edit":
            let file = input?.filePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            return "Editing \(file ?? "file")"
        case "Write":
            let file = input?.filePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            return "Writing \(file ?? "file")"
        case "Read":
            let file = input?.filePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            return "Reading \(file ?? "file")"
        case "Bash":
            let cmd = input?.command?.prefix(40)
            return "Running \(cmd ?? "command")..."
        case "Grep":
            let pattern = input?.pattern ?? ""
            return "Searching \"\(pattern)\""
        case "Glob":
            let pattern = input?.pattern ?? ""
            return "Finding \(pattern)"
        case "Agent":
            let desc = input?.description ?? "subagent"
            return "Agent: \(desc)"
        default:
            return toolName
        }
    }

    func parseEvent(from payload: HookPayload) -> AgentEvent? {
        let eventType: EventType = switch payload.hookEventName {
        case "PreToolUse":  .toolCall
        case "PostToolUse": .toolResult
        case "Stop":        .message
        default:            .message
        }

        return AgentEvent(
            id: payload.toolUseId ?? UUID().uuidString,
            sessionId: payload.sessionId,
            timestamp: Date(),
            type: eventType,
            toolName: payload.toolName,
            inputSummary: describeAction(from: payload),
            outputSummary: nil,  // PostToolUse 时从 toolResponse 提取
            tokensUsed: nil,     // 从 transcript 或 API 统计
            durationMs: nil      // Pre→Post 时间差计算
        )
    }

    func updateSession(
        from payload: HookPayload,
        existing: AgentSession?
    ) -> AgentSession {
        if let session = existing {
            var updated = session
            switch payload.hookEventName {
            case "PreToolUse":
                updated.status = .running
                updated.currentAction = describeAction(from: payload)
            case "Stop":
                updated.status = .completed
                updated.endedAt = Date()
            default:
                break
            }
            return updated
        } else {
            return AgentSession(
                id: payload.sessionId,
                agentType: .claudeCode,
                status: .running,
                projectDir: payload.cwd,
                startedAt: Date(),
                currentAction: describeAction(from: payload),
                todoProgress: nil
            )
        }
    }
}
```

---

## 7. 数据存储 (GRDB + SQLite)

### 7.1 数据库位置

```
~/Library/Application Support/AgentWatchTower/watchtower.sqlite
```

### 7.2 Schema

```sql
-- 会话表
CREATE TABLE agent_session (
    id              TEXT PRIMARY KEY,
    agent_type      TEXT NOT NULL DEFAULT 'claude-code',
    status          TEXT NOT NULL DEFAULT 'running',
    project_dir     TEXT NOT NULL,
    current_action  TEXT,
    todo_completed  INTEGER,
    todo_total      INTEGER,
    model           TEXT,
    started_at      REAL NOT NULL,   -- Unix timestamp
    ended_at        REAL,
    updated_at      REAL NOT NULL
);

CREATE INDEX idx_session_status ON agent_session(status);
CREATE INDEX idx_session_started ON agent_session(started_at);

-- 事件表
CREATE TABLE agent_event (
    id              TEXT PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES agent_session(id),
    timestamp       REAL NOT NULL,
    event_type      TEXT NOT NULL,    -- 'tool_call', 'tool_result', 'message', 'error'
    tool_name       TEXT,
    input_summary   TEXT,
    output_summary  TEXT,
    tokens_input    INTEGER,
    tokens_output   INTEGER,
    duration_ms     INTEGER,
    raw_payload     TEXT              -- 完整 JSON 备查
);

CREATE INDEX idx_event_session ON agent_event(session_id);
CREATE INDEX idx_event_time ON agent_event(timestamp);

-- 日用量汇总表（定期聚合，避免实时查询全表）
CREATE TABLE daily_usage (
    date            TEXT NOT NULL,    -- 'YYYY-MM-DD'
    agent_type      TEXT NOT NULL,
    total_sessions  INTEGER DEFAULT 0,
    tokens_input    INTEGER DEFAULT 0,
    tokens_output   INTEGER DEFAULT 0,
    api_calls       INTEGER DEFAULT 0,
    estimated_cost  REAL DEFAULT 0,
    PRIMARY KEY (date, agent_type)
);
```

### 7.3 GRDB Record 定义

```swift
// Database.swift
import GRDB

struct AppDatabase {
    let dbQueue: DatabaseQueue

    init() throws {
        let path = AppDatabase.databasePath()
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "agent_session") { t in
                t.primaryKey("id", .text)
                t.column("agent_type", .text).notNull().defaults(to: "claude-code")
                t.column("status", .text).notNull().defaults(to: "running")
                t.column("project_dir", .text).notNull()
                t.column("current_action", .text)
                t.column("todo_completed", .integer)
                t.column("todo_total", .integer)
                t.column("model", .text)
                t.column("started_at", .double).notNull()
                t.column("ended_at", .double)
                t.column("updated_at", .double).notNull()
            }

            try db.create(table: "agent_event") { t in
                t.primaryKey("id", .text)
                t.column("session_id", .text).notNull()
                    .references("agent_session", onDelete: .cascade)
                t.column("timestamp", .double).notNull()
                t.column("event_type", .text).notNull()
                t.column("tool_name", .text)
                t.column("input_summary", .text)
                t.column("output_summary", .text)
                t.column("tokens_input", .integer)
                t.column("tokens_output", .integer)
                t.column("duration_ms", .integer)
                t.column("raw_payload", .text)
            }

            try db.create(table: "daily_usage") { t in
                t.primaryKey {
                    t.column("date", .text)
                    t.column("agent_type", .text)
                }
                t.column("total_sessions", .integer).defaults(to: 0)
                t.column("tokens_input", .integer).defaults(to: 0)
                t.column("tokens_output", .integer).defaults(to: 0)
                t.column("api_calls", .integer).defaults(to: 0)
                t.column("estimated_cost", .double).defaults(to: 0)
            }
        }

        return migrator
    }

    static func databasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("AgentWatchTower")
        try? FileManager.default.createDirectory(
            at: appSupport, withIntermediateDirectories: true
        )
        return appSupport.appendingPathComponent("watchtower.sqlite").path
    }
}
```

### 7.4 数据保留策略

- 默认保留 30 天事件明细（可在 Settings 中配置）
- `daily_usage` 汇总表永久保留
- 后台定时清理过期 `agent_event` 记录

---

## 8. 并发模型

全面使用 Swift Concurrency（async/await + Actor），避免手动锁。

```
┌─────────────────────────────────────────────────────┐
│                Main Actor (@MainActor)               │
│                                                     │
│   SwiftUI Views ←→ ViewModels                       │
│   StatusBarController                               │
│   PopoverManager / FloatingPanelController          │
└─────────────────────────┬───────────────────────────┘
                          │ async calls
┌─────────────────────────┴───────────────────────────┐
│              EventProcessor (Actor)                   │
│                                                     │
│   接收 HTTP 事件 → Adapter 转换 → 写入 Storage       │
│   → 通知 ViewModel 更新                              │
└─────────────────────────┬───────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────┐
│           Background (nonisolated)                    │
│                                                     │
│   EventServer (HTTP listener)                        │
│   Database I/O (GRDB 内部队列)                       │
└─────────────────────────────────────────────────────┘
```

### EventProcessor Actor

核心事件处理器，保证事件的串行处理和状态一致性：

```swift
actor EventProcessor {
    private let sessionStore: SessionStore
    private let eventStore: EventStore
    private let adapters: [String: AgentAdapter]  // agentType → adapter
    private var pendingToolCalls: [String: Date]   // toolUseId → startTime

    /// 处理一条来自 HTTP Server 的原始事件
    func process(_ payload: HookPayload) async {
        let adapter = adapters["claude-code"]!  // Phase 1 只有 Claude Code

        // 1. 更新 Session
        let existing = try? await sessionStore.find(id: payload.sessionId)
        let session = adapter.updateSession(from: payload, existing: existing)
        try? await sessionStore.upsert(session)

        // 2. 创建 Event
        if let event = adapter.parseEvent(from: payload) {
            // 计算 Tool Call 耗时：Pre→Post 时间差
            var finalEvent = event
            if payload.hookEventName == "PreToolUse", let toolId = payload.toolUseId {
                pendingToolCalls[toolId] = Date()
            }
            if payload.hookEventName == "PostToolUse", let toolId = payload.toolUseId {
                if let startTime = pendingToolCalls.removeValue(forKey: toolId) {
                    finalEvent.durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                }
            }
            try? await eventStore.insert(finalEvent)
        }

        // 3. 通知 UI 刷新（切换到 MainActor）
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sessionDidUpdate,
                object: nil,
                userInfo: ["sessionId": payload.sessionId]
            )
        }
    }
}
```

---

## 9. ViewModel 层

### SessionListViewModel

```swift
// SessionListViewModel.swift
@Observable
@MainActor
final class SessionListViewModel {
    var activeSessions: [AgentSession] = []
    var dailyTokens: Int = 0
    var dailyCost: Double = 0.0

    private let sessionStore: SessionStore
    private let usageStore: DailyUsageStore

    init(sessionStore: SessionStore, usageStore: DailyUsageStore) {
        self.sessionStore = sessionStore
        self.usageStore = usageStore

        // 监听事件更新通知
        NotificationCenter.default.addObserver(
            forName: .sessionDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.reload() }
        }
    }

    func reload() async {
        // 查询所有非 completed 会话 + 今日 completed
        activeSessions = (try? await sessionStore.activeSessions()) ?? []

        let today = Calendar.current.startOfDay(for: Date())
        let usage = try? await usageStore.usage(for: today)
        dailyTokens = (usage?.tokensInput ?? 0) + (usage?.tokensOutput ?? 0)
        dailyCost = usage?.estimatedCost ?? 0
    }
}
```

---

## 10. 费用计算

```swift
// CostCalculator.swift
struct CostCalculator {
    struct ModelPricing {
        let inputPerMToken: Double   // $ per 1M input tokens
        let outputPerMToken: Double  // $ per 1M output tokens
    }

    static let pricing: [String: ModelPricing] = [
        // Claude models
        "claude-opus-4-6":   ModelPricing(inputPerMToken: 15.0,  outputPerMToken: 75.0),
        "claude-sonnet-4-6": ModelPricing(inputPerMToken: 3.0,   outputPerMToken: 15.0),
        "claude-haiku-4-5":  ModelPricing(inputPerMToken: 0.80,  outputPerMToken: 4.0),
        // Gemini models (Phase 2)
        "gemini-2.0-flash":  ModelPricing(inputPerMToken: 0.10,  outputPerMToken: 0.40),
        "gemini-2.5-pro":    ModelPricing(inputPerMToken: 1.25,  outputPerMToken: 10.0),
    ]

    static func estimate(
        model: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> Double {
        guard let price = pricing[model] else { return 0 }
        let inputCost = Double(inputTokens) / 1_000_000 * price.inputPerMToken
        let outputCost = Double(outputTokens) / 1_000_000 * price.outputPerMToken
        return inputCost + outputCost
    }
}
```

---

## 11. SPM 依赖

```swift
// Package.swift
let package = Package(
    name: "AgentWatchTower",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentWatchTower",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Swifter", package: "swifter"),
            ]
        ),
        .testTarget(
            name: "AgentWatchTowerTests",
            dependencies: ["AgentWatchTower"]
        ),
    ]
)
```

---

## 12. 应用启动流程

```
App Launch
    │
    ├─ 1. AppDelegate.applicationDidFinishLaunching
    │      ├─ 初始化 AppDatabase (GRDB, run migrations)
    │      ├─ 创建 SessionStore, EventStore
    │      ├─ 创建 EventProcessor (Actor)
    │      ├─ 创建 EventServer (HTTP :19280)
    │      │    └─ server.start()
    │      ├─ 创建 StatusBarController (NSStatusItem)
    │      ├─ 创建 PopoverManager
    │      ├─ 创建 FloatingPanelController
    │      ├─ 创建 PinStateManager
    │      └─ 创建 ViewModels, 注入依赖
    │
    ├─ 2. StatusBarController 就绪
    │      └─ 菜单栏出现图标 🗼
    │
    ├─ 3. EventServer 监听 localhost:19280
    │      └─ 等待 Claude Code Hook 事件
    │
    └─ 4. 用户点击菜单栏图标
           └─ PopoverManager.toggle() → 显示面板
```

---

## 13. 安全与沙盒

### App Sandbox 配置

```xml
<!-- AgentWatchTower.entitlements -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- 监听本地 HTTP 端口 -->
    <key>com.apple.security.network.server</key>
    <true/>

    <!-- 读取 ~/.claude/settings.json 写入 Hook 配置 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

**注意**：如果 App Sandbox 对 `~/.claude/` 访问有限制，Hook 安装功能可能需要通过 NSOpenPanel 让用户主动授权，或者考虑非沙盒分发（直接 .app 或 Homebrew Cask）。

### 数据安全
- 所有数据本地存储，不联网上传
- `raw_payload` 中可能包含代码片段，仅存本地 SQLite
- 面板 UI 中不展示 API Key、Token 等敏感信息
- 数据库文件权限 600（仅当前用户可读写）

---

## 14. 数据采集方案对比：Hooks vs SDK vs Transcript

### 14.1 方案对比

| 维度 | HTTP Hooks（采用） | Claude Agent SDK | Transcript 解析（增强） |
|------|-------------------|-----------------|----------------------|
| 数据来源 | Claude Code 主动推送 | SDK 子进程 stream events | `~/.claude/projects/.../transcript.jsonl` |
| 监控对象 | 用户已启动的任意会话 | 仅限由 SDK 启动的会话 | 有 transcript_path 的会话 |
| 对用户工作流影响 | **零** — 用户照常在终端使用 | **大** — 必须通过 Watch Tower 启动 | **零** — 只读文件 |
| 实时性 | 工具调用前后（离散事件） | 逐 token 流式推送 | 非实时（文件写入后读取） |
| 可获取数据 | tool_name, tool_input, tool_response, session_id, cwd | 全部 stream events (thinking, text, tool) | stop_reason, token usage, 完整对话历史 |
| Thinking 状态 | 间接推断（PreToolUse 间隔） | 直接收到 stream event | 无法实时获取 |
| stop_reason | **无** | 有（end_turn, max_tokens, tool_use） | **有** |
| Token 用量 | **无**（Hook payload 不含） | 有（message_delta.usage） | **有**（每条消息的 usage） |
| 编程语言 | 任意（HTTP 接收端） | Python / TypeScript（无官方 Swift SDK） | Swift（直接读文件） |

### 14.2 结论：Hooks 为主 + Transcript 解析增强

```
┌─────────────────────────────────────────────────────┐
│              数据采集架构（最终方案）                    │
│                                                     │
│   ┌──────────────────────────────────────────┐      │
│   │         HTTP Hooks（主数据源）             │      │
│   │   实时事件：PreToolUse / PostToolUse      │      │
│   │   会话生命周期：SessionStart / Stop        │      │
│   │   通知：Notification                      │      │
│   │   子 Agent：SubagentStart / SubagentStop  │      │
│   └─────────────────┬────────────────────────┘      │
│                     │                               │
│                     ▼                               │
│   ┌──────────────────────────────────────────┐      │
│   │     Transcript 解析（补充数据源）          │      │
│   │   触发时机：收到 Stop 事件时               │      │
│   │   ✅ stop_reason → 精确状态判断           │      │
│   │   ✅ usage → 精确 token 用量             │      │
│   │   ✅ 完整工具调用历史                     │      │
│   └──────────────────────────────────────────┘      │
│                                                     │
│   Claude Agent SDK → 暂不引入                       │
│     原因：                                          │
│     1. 要求由 SDK 启动会话，改变用户工作流（核心矛盾）  │
│     2. 无官方 Swift SDK，需引入 Node.js/Python 边车   │
│     3. 未来 Phase 3 可考虑 SDK 模式提供               │
│        "Watch Tower 内置终端" 功能                   │
└─────────────────────────────────────────────────────┘
```

**不引入 SDK 的原因**：

1. **核心矛盾** — SDK 要求由它来启动 Claude Code 子进程，用户无法在自己的终端中交互
2. **语言不匹配** — SDK 仅支持 Python/TypeScript，而本项目是 Swift 原生应用，需要引入额外的 Node.js/Python sidecar 进程
3. **复杂度过高** — 为了获取 thinking stream 而引入跨语言进程通信，收益不足以抵消架构成本
4. **Transcript 可补充** — SDK 的核心优势（stop_reason、token usage）可通过解析 transcript JSONL 文件获得

### 14.3 Transcript 解析器

Claude Code 的 Hook stdin 包含 `transcript_path` 字段，指向完整的会话 JSONL 文件。在收到 `Stop` 事件时解析此文件，可补充 Hook 事件缺失的数据：

```swift
// TranscriptParser.swift

/// 解析 Claude Code 的 transcript.jsonl 文件，
/// 提取 stop_reason、token usage 等 Hook 事件中缺失的数据
struct TranscriptParser {

    struct TranscriptEntry: Codable {
        let type: String                 // "human", "assistant"
        let message: MessageContent?
    }

    struct MessageContent: Codable {
        let role: String?
        let content: [ContentBlock]?
        let stopReason: String?          // "end_turn", "max_tokens", "tool_use"
        let usage: UsageInfo?

        enum CodingKeys: String, CodingKey {
            case role, content
            case stopReason = "stop_reason"
            case usage
        }
    }

    struct UsageInfo: Codable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    struct ContentBlock: Codable {
        let type: String                 // "text", "tool_use", "tool_result"
        let name: String?               // tool name (for tool_use blocks)
    }

    struct ParseResult {
        let lastStopReason: String?
        let totalUsage: UsageInfo
        let toolCallCount: Int
    }

    /// 解析 transcript JSONL 文件
    /// 只读取最后 N 行以保证性能（transcript 可能很大）
    func parse(_ path: String, tailLines: Int = 50) throws -> ParseResult {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let lines = String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .suffix(tailLines) ?? []

        var lastStopReason: String?
        var totalInput = 0
        var totalOutput = 0
        var toolCalls = 0

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(
                      TranscriptEntry.self, from: lineData
                  ) else { continue }

            if let msg = entry.message {
                if let usage = msg.usage {
                    totalInput += usage.inputTokens
                    totalOutput += usage.outputTokens
                }
                if entry.type == "assistant", let reason = msg.stopReason {
                    lastStopReason = reason
                }
                toolCalls += msg.content?
                    .filter { $0.type == "tool_use" }.count ?? 0
            }
        }

        return ParseResult(
            lastStopReason: lastStopReason,
            totalUsage: UsageInfo(
                inputTokens: totalInput,
                outputTokens: totalOutput
            ),
            toolCallCount: toolCalls
        )
    }
}
```

### 14.4 EventProcessor 中集成 Transcript 解析

```swift
// EventProcessor 中 Stop 事件的增强处理
func process(_ payload: HookPayload) async {
    let adapter = adapters["claude-code"]!

    // 1. 常规 Hook 事件处理（同 §8）
    let existing = try? await sessionStore.find(id: payload.sessionId)
    let session = adapter.updateSession(from: payload, existing: existing)

    // 2. Stop 事件：解析 transcript 补充数据
    if payload.hookEventName == "Stop",
       let transcriptPath = payload.transcriptPath {
        let parser = TranscriptParser()
        if let result = try? parser.parse(transcriptPath) {
            // 精确的完成状态（替代简单的 .completed）
            session.status = switch result.lastStopReason {
            case "end_turn":    .completed
            case "max_tokens":  .error       // token 超限视为异常
            default:            .completed
            }

            // 精确的 token 用量
            session.tokensInput = result.totalUsage.inputTokens
            session.tokensOutput = result.totalUsage.outputTokens
        }
    }

    try? await sessionStore.upsert(session)
    // ... 后续事件存储和 UI 通知同 §8
}
```

### 14.5 对用户工作流的影响

**零影响**。具体分析：

| 场景 | 行为 | 对用户的影响 |
|------|------|-------------|
| 正常使用 | Watch Tower 通过 HTTP Hooks 静默接收事件 | 无感 |
| Watch Tower 未运行 | HTTP 请求失败，Claude Code 5s 超时后跳过 | 无感（可能有微小延迟） |
| Watch Tower 崩溃 | 同上，Hook 失败不影响 Claude Code | 无感 |
| 安装 Hooks | 追加到 `~/.claude/settings.json`，不覆盖已有配置 | 一次性配置 |
| 卸载 Hooks | 只移除 Watch Tower 的 hook 条目 | 一键还原 |
| Transcript 读取 | 只在 Stop 事件时只读访问，不修改文件 | 无感 |

---

## 15. 测试策略

| 层级 | 测试内容 | 方法 |
|------|---------|------|
| Adapter | HookPayload 解析、Action 描述生成 | Unit Test，用 JSON fixture |
| Storage | CRUD、Migration、数据过期清理 | Unit Test，in-memory SQLite |
| EventProcessor | 事件串行处理、Pre→Post 耗时计算 | Unit Test，Mock Store |
| Server | HTTP 路由、JSON 解析、错误处理 | Integration Test，本地 HTTP |
| HookInstaller | 配置合并、去重、卸载 | Unit Test，临时文件 |
| UI | 卡片渲染、Pin 切换、动画 | Xcode Preview + 手动验证 |

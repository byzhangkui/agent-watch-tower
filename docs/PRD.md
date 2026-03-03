# Agent Watch Tower - 产品需求文档 (PRD)

## 1. 概述

### 1.1 产品定位
Agent Watch Tower 是一款 **macOS 原生应用**，以 Menu Bar 常驻 + 可 Pin 悬浮窗的形态，帮助开发者实时监控 AI Agent 的工作状态。首期支持 Claude Code，后续扩展 Gemini 等更多 Agent。

### 1.2 目标用户
- 使用 AI Agent 辅助开发的工程师
- 管理多个 Agent 实例的团队 Lead
- 需要追踪 Agent 使用成本的项目管理者

### 1.3 核心价值
| 痛点 | 解决方案 |
|------|----------|
| Agent 在后台运行，不知道进度 | Menu Bar 常驻图标 + 悬浮窗置顶，随时可见 |
| 多个 Agent 同时工作，切换混乱 | 统一监控视图，集中管理 |
| Token 消耗不透明 | 用量统计与成本分析 |
| 任务失败难以排查 | 完整的操作日志与错误追踪 |
| 监控工具本身占用大量资源 | Swift 原生实现，内存 < 20MB |

### 1.4 产品形态
Menu Bar 应用 + 可分离的悬浮面板，两种模式可自由切换：

- **Menu Bar 模式**：点击菜单栏图标弹出下拉面板，点击其他区域自动收起
- **Pin 悬浮模式**：点击 Pin 按钮后面板脱离 Menu Bar，变为 always-on-top 悬浮窗，可拖拽到屏幕任意位置

---

## 2. 功能规划

### 2.1 Phase 1 — Claude Code 监控（MVP）

#### 2.1.1 Menu Bar 常驻
- 菜单栏显示简洁图标，运行中时图标带动画（脉冲效果）
- 图标旁可选择性显示当前活跃 Agent 数量

#### 2.1.2 简要面板（Menu Bar 下拉 / 悬浮窗）
- 展示所有活跃的 Claude Code 会话列表
- 每个会话卡片：状态指示灯、Agent 类型、项目目录名、当前动作、任务进度条
- 底部显示今日汇总（Token 用量、费用）
- Pin 按钮：切换悬浮 / 收起模式

#### 2.1.3 详情弹窗
- 点击会话卡片展开详情
- 实时事件时间线（Thinking / Tool Call / Message）
- 工具调用分布统计
- Token 消耗明细

#### 2.1.4 数据采集
- 利用 Claude Code 的 **Hooks 机制**：
  - `PreToolUse` / `PostToolUse`：捕获工具调用事件
  - `Notification`：捕获任务完成、错误等通知
- Hook 脚本通过 Unix Domain Socket 或 HTTP 将事件推送到本地运行的 Watch Tower 进程
- 本地 SQLite 存储历史事件数据

### 2.2 Phase 2 — 多 Agent 支持

#### 2.2.1 Gemini Agent 接入
- 实现 Gemini Adapter，适配 Gemini 的事件格式
- 面板中通过不同颜色/图标区分 Agent 类型

#### 2.2.2 跨 Agent 对比
- 同一任务在不同 Agent 上的表现对比
- Token 消耗对比、完成速度对比

### 2.3 Phase 3 — 高级功能
- macOS 原生通知：Token 超限、长时间无响应、任务完成/失败
- 历史趋势分析（独立设置窗口中展示图表）

---

## 3. 技术架构

### 3.1 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                   macOS Native App                        │
│                  (Swift + SwiftUI)                        │
│                                                          │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Menu Bar    │  │  Floating    │  │  Settings      │   │
│  │ Popover     │  │  Panel       │  │  Window        │   │
│  │ (NSPopover) │  │  (NSPanel)   │  │  (NSWindow)    │   │
│  └──────┬──────┘  └──────┬───────┘  └───────┬────────┘   │
│         └────────────────┼──────────────────┘            │
│                          │                               │
│                ┌─────────┴─────────┐                     │
│                │   ViewModel Layer  │                     │
│                │   (ObservableObject)│                    │
│                └─────────┬─────────┘                     │
│                          │                               │
│         ┌────────────────┼────────────────┐              │
│         │                │                │              │
│  ┌──────┴──────┐  ┌─────┴──────┐  ┌─────┴──────┐       │
│  │  Local HTTP │  │  SQLite    │  │  Agent     │       │
│  │  Server     │  │  Storage   │  │  Adapters  │       │
│  │  (Vapor/    │  │  (GRDB)    │  │            │       │
│  │   Swifter)  │  │            │  │            │       │
│  └─────────────┘  └────────────┘  └────────────┘       │
│                                                          │
└──────────────────────────────────────────────────────────┘
          ▲                                    ▲
          │ HTTP POST events                   │ API / Logs
          │                                    │
┌─────────┴─────────┐              ┌──────────┴──────────┐
│  Claude Code      │              │  Gemini Agent       │
│  Hooks Scripts    │              │  (Phase 2)          │
│  (bash/python)    │              │                     │
└───────────────────┘              └─────────────────────┘
```

### 3.2 数据采集方案

#### Claude Code Hooks
在 `~/.claude/settings.json` 中配置 Hooks：

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "curl -s -X POST http://localhost:19280/events -d '{\"type\":\"pre_tool\",\"tool\":\"$CLAUDE_TOOL_NAME\",\"session\":\"$CLAUDE_SESSION_ID\"}'"
      }]
    }],
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "curl -s -X POST http://localhost:19280/events -d '{\"type\":\"post_tool\",\"tool\":\"$CLAUDE_TOOL_NAME\",\"session\":\"$CLAUDE_SESSION_ID\"}'"
      }]
    }],
    "Notification": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "curl -s -X POST http://localhost:19280/events -d '{\"type\":\"notification\",\"session\":\"$CLAUDE_SESSION_ID\"}'"
      }]
    }]
  }
}
```

App 内嵌轻量 HTTP Server（端口 19280），接收来自 Hook 脚本的事件上报。

#### Gemini（Phase 2）
- 封装 Gemini API 调用层，在请求/响应中插入事件采集
- 或通过 Gemini CLI 的日志文件监控

### 3.3 数据模型

```swift
// MARK: - Core Models

enum AgentType: String, Codable {
    case claudeCode = "claude-code"
    case gemini = "gemini"
}

enum SessionStatus: String, Codable {
    case running, idle, completed, error
}

enum EventType: String, Codable {
    case thinking, toolCall, toolResult, message, error
}

struct AgentSession: Identifiable, Codable {
    let id: String
    let agentType: AgentType
    var status: SessionStatus
    let projectDir: String
    let startedAt: Date
    var endedAt: Date?
    var currentAction: String?     // e.g. "Editing auth.ts"
    var todoProgress: TodoProgress?
}

struct TodoProgress: Codable {
    let completed: Int
    let total: Int
}

struct AgentEvent: Identifiable, Codable {
    let id: String
    let sessionId: String
    let timestamp: Date
    let type: EventType
    let toolName: String?
    let inputSummary: String?
    let outputSummary: String?
    let tokensUsed: TokenUsage?
    let durationMs: Int?
}

struct TokenUsage: Codable {
    let input: Int
    let output: Int
}
```

### 3.4 技术选型

| 层级 | 选型 | 理由 |
|------|------|------|
| 语言 | Swift 5.9+ | macOS 原生，性能最佳 |
| UI 框架 | SwiftUI | 声明式 UI，开发效率高 |
| Menu Bar | NSStatusItem + NSPopover | macOS 标准 Menu Bar 实现 |
| 悬浮窗 | NSPanel (NSFloatingWindowLevel) | 原生 always-on-top 支持 |
| 本地数据库 | GRDB.swift (SQLite) | Swift 原生 SQLite 封装，轻量高效 |
| 本地 HTTP | Swifter 或 Embassy | 轻量级内嵌 HTTP 服务器，接收 Hook 事件 |
| 架构模式 | MVVM | SwiftUI 最佳实践 |
| 最低系统版本 | macOS 14 (Sonoma) | 使用最新 SwiftUI API |

---

## 4. 非功能需求

- **性能**：内存占用 < 20MB，CPU 空闲时 < 1%
- **延迟**：事件从 Hook 触发到面板更新 < 200ms
- **可扩展**：新增 Agent 类型只需实现 `AgentAdapter` 协议
- **数据安全**：所有数据仅存储在本地，不上传任何信息
- **系统集成**：支持 macOS 原生深色/浅色模式自动切换

---

## 5. 里程碑

| 阶段 | 内容 | 预期产出 |
|------|------|----------|
| M1 | Xcode 项目脚手架 + Menu Bar 基础框架 | 菜单栏图标 + 空白弹窗 |
| M2 | 内嵌 HTTP Server + Claude Code Hook 配置 | 能接收并存储 Claude Code 事件 |
| M3 | 简要面板 UI + 悬浮窗 Pin 功能 | Menu Bar 下拉 ↔ 悬浮窗切换 |
| M4 | 详情视图 + 事件时间线 | 完整的 Claude Code 监控体验 |
| M5 | Gemini 接入 | 支持 Gemini Agent 监控 |
| M6 | 统计分析 + 原生通知 | 趋势图表、费用分析、告警 |

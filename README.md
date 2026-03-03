# Agent Watch Tower

macOS 原生菜单栏应用，实时监控 AI Agent（Claude Code / Gemini）的运行状态、工具调用和 Token 消耗。

```
  🗼 ← 菜单栏常驻图标（运行中脉冲动画）
   │
   ▼ 点击展开
 ┌──────────────────────────────────────┐
 │  Agent Watch Tower               📌  │
 │  Today: 15.2k tokens · $0.46        │
 ├──────────────────────────────────────┤
 │  ● claude-code           ⏱ 23m      │
 │    my-project/                       │
 │    ▶ Editing auth.ts                 │
 │    ████████████░░░░░░  5/8 tasks     │
 │    Tokens: 3.2k in · 1.8k out       │
 ├──────────────────────────────────────┤
 │  ● claude-code           ⏱ 8m       │
 │    api-server/                       │
 │    💭 Thinking...                    │
 │    ██████░░░░░░░░░░░░  2/10 tasks    │
 └──────────────────────────────────────┘
```

## 功能特性

- **菜单栏监控** — 图标实时反映 Agent 状态（空闲 / 运行中脉冲 / 错误警告），显示活跃数量
- **会话卡片** — 项目目录、当前动作、任务进度条、Token 用量一目了然
- **Pin 悬浮窗** — Popover ↔ 独立悬浮窗一键切换，always-on-top 不遮挡工作
- **详情时间线** — 每个工具调用的输入/输出、耗时、Token 消耗，支持展开查看
- **工具分布图** — Edit / Read / Bash / Grep 等工具使用频次可视化
- **费用估算** — 基于模型定价自动计算 Token 花费
- **一键 Hook 安装** — 自动配置 `~/.claude/settings.json`，无需手动编辑
- **数据本地存储** — SQLite 数据库，所有数据留在本机，无遥测

## 系统要求

- macOS 14 (Sonoma) 或更高
- Swift 5.9+（仅构建时需要）
- Claude Code（被监控的 Agent）

## 快速开始

### 1. 构建安装

```bash
git clone <repo-url> && cd agent-watch-tower

# 构建 .app 并安装到 /Applications
make install

# 或仅构建不安装
make bundle
# 产物: .build/AgentWatchTower.app
```

### 2. 启动应用

```bash
make run-release
# 或双击 /Applications/AgentWatchTower.app
```

菜单栏出现 🗼 图标即为运行成功。

### 3. 安装 Hook

点击菜单栏图标 → 面板底部 **Settings** → **Agents** → **Install Hooks**

或手动检查 Hook 状态：

```bash
make hooks-check
```

安装后 `~/.claude/settings.json` 会自动添加以下 Hook 配置：

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "", "hooks": [{ "type": "http", "url": "http://localhost:19280/events/pre-tool-use", "timeout": 5 }] }],
    "PostToolUse": [...],
    "Stop": [...],
    "SessionStart": [...],
    "Notification": [...],
    "SubagentStart": [...],
    "SubagentStop": [...]
  }
}
```

### 4. 开始使用

正常使用 Claude Code 即可。每次 Agent 运行时，Watch Tower 自动接收事件并实时更新面板。

## 构建命令

| 命令 | 说明 |
|---|---|
| `make build` | Debug 构建 |
| `make release` | Release 优化构建 |
| `make bundle` | 构建 Release + 组装 `.app` 包 |
| `make sign` | Ad-hoc 代码签名 |
| `make sign-dev` | Apple Development 证书签名 |
| `make install` | 签名 + 安装到 `/Applications` |
| `make run` | Debug 构建并直接运行 |
| `make run-release` | 构建 `.app` 并启动 |
| `make test` | 运行测试 |
| `make lint` | SwiftLint 检查（需已安装） |
| `make format` | swift-format 格式化（需已安装） |
| `make clean` | 清理构建产物 |
| `make resolve` | 解析 SPM 依赖 |
| `make update` | 更新 SPM 依赖 |
| `make help` | 查看所有命令 |

## 架构

```
Sources/
├── App/                 # @main 入口 + AppDelegate 依赖注入
├── Models/              # AgentSession, AgentEvent, DailyUsage
├── Storage/             # GRDB/SQLite 持久化层
├── Server/              # Swifter HTTP 服务器 + EventProcessor Actor
├── Adapters/            # AgentAdapter 协议 + ClaudeCodeAdapter
├── Utilities/           # HookInstaller, CostCalculator, TranscriptParser
├── Window/              # StatusBar, Popover, FloatingPanel, PinState
├── ViewModels/          # @Observable MVVM
└── Views/
    ├── Panel/           # 会话列表、卡片、日汇总
    ├── Detail/          # 事件时间线、工具分布图
    ├── Settings/        # 设置窗口
    └── Components/      # 状态指示灯、进度条、Token 标签
```

### 数据流

```
Claude Code Hook 事件
  → HTTP POST localhost:19280
    → EventServer (Swifter)
      → EventRouter
        → EventProcessor (Swift Actor，串行处理)
          → ClaudeCodeAdapter 转为统一模型
            → GRDB 写入 SQLite
              → NotificationCenter 通知
                → @Observable ViewModel 刷新
                  → SwiftUI 自动重绘
```

### 并发模型

| 组件 | 线程策略 |
|---|---|
| SwiftUI Views / ViewModels | `@MainActor` |
| EventProcessor | Swift `actor`（串行处理事件） |
| GRDB | 内部 DatabaseQueue（串行写入） |
| Swifter HTTP | 自管理线程池 |

### 依赖

| 库 | 版本 | 用途 |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | 7.0+ | SQLite ORM + 迁移 |
| [Swifter](https://github.com/httpswift/swifter) | 1.5+ | 轻量 HTTP 服务器 |

## 配置

| 项目 | 默认值 | 说明 |
|---|---|---|
| HTTP 端口 | `19280` | Hook 事件接收端口 |
| 数据库路径 | `~/Library/Application Support/AgentWatchTower/watchtower.sqlite` | SQLite 文件位置 |
| 数据保留 | 30 天 | 过期事件自动清理 |
| 面板尺寸 | 320 × 420pt | 默认；Pin 模式可拖拽调整 |

## 监控的事件类型

| Hook 事件 | 对应操作 |
|---|---|
| `PreToolUse` | 工具调用开始 → 更新当前动作 |
| `PostToolUse` | 工具调用完成 → 记录结果、耗时 |
| `SessionStart` | 新会话开始 → 创建会话卡片 |
| `Stop` | 会话结束 → 解析 transcript 获取精确 Token |
| `Notification` | 通知事件 |
| `SubagentStart/Stop` | 子 Agent 生命周期 |

## 路线图

| 阶段 | 内容 | 状态 |
|---|---|---|
| M1 | Menu Bar 基础框架 | ✅ |
| M2 | HTTP Server + Hook 配置 | ✅ |
| M3 | 简要面板 UI + Pin 悬浮窗 | ✅ |
| M4 | 详情视图 + 事件时间线 | ✅ |
| M5 | Gemini Agent 接入 | 计划中 |
| M6 | 统计分析 + 原生通知 | 计划中 |

## License

MIT

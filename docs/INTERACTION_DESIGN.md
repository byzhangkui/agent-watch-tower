# Agent Watch Tower - 交互设计

## 1. 页面结构

整体采用经典的 Dashboard 布局：左侧导航 + 右侧内容区。

```
┌──────────────────────────────────────────────────────────────┐
│  🗼 Agent Watch Tower                    [Settings] [Theme]  │
├────────────┬─────────────────────────────────────────────────┤
│            │                                                 │
│  Dashboard │              主内容区                            │
│            │                                                 │
│  Sessions  │                                                 │
│            │                                                 │
│  Analytics │                                                 │
│            │                                                 │
│  Settings  │                                                 │
│            │                                                 │
└────────────┴─────────────────────────────────────────────────┘
```

---

## 2. 核心页面

### 2.1 Dashboard（总览页）

用户打开面板后的第一个页面，一眼掌握全局。

```
┌─ Dashboard ──────────────────────────────────────────────────┐
│                                                              │
│  ┌─ Active Agents ──┐ ┌─ Today ─────────┐ ┌─ Cost ────────┐ │
│  │                  │ │                  │ │               │ │
│  │    3 Running     │ │  12,450 Tokens   │ │   $0.37       │ │
│  │    1 Idle        │ │  48 Tool Calls   │ │   today       │ │
│  │    2 Completed   │ │  3 Sessions      │ │               │ │
│  └──────────────────┘ └──────────────────┘ └───────────────┘ │
│                                                              │
│  ┌─ Live Sessions ───────────────────────────────────────┐   │
│  │                                                       │   │
│  │  ● claude-code  session-a1b2  my-project/             │   │
│  │    Status: Running · Tool: Edit file · 2m ago         │   │
│  │    ████████████░░░░  5/8 tasks                        │   │
│  │                                                       │   │
│  │  ● claude-code  session-c3d4  api-server/             │   │
│  │    Status: Thinking · 30s ago                         │   │
│  │    ████░░░░░░░░░░░░  2/10 tasks                      │   │
│  │                                                       │   │
│  │  ○ claude-code  session-e5f6  docs/                   │   │
│  │    Status: Idle · Waiting for user · 5m ago           │   │
│  │                                                       │   │
│  │  ◆ gemini       session-g7h8  ml-pipeline/            │   │
│  │    Status: Running · Generating code · 1m ago         │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ Token Usage (7 days) ────────────────────────────────┐   │
│  │                                                       │   │
│  │  10k │          ╭──╮                                  │   │
│  │      │     ╭──╮ │  │ ╭──╮                             │   │
│  │   5k │╭──╮ │  │ │  │ │  │ ╭──╮                       │   │
│  │      ││  │ │  │ │  │ │  │ │  │ ╭──╮                  │   │
│  │   0  │┴──┴─┴──┴─┴──┴─┴──┴─┴──┴─┴──┴─                │   │
│  │       Mon  Tue  Wed  Thu  Fri  Sat  Sun               │   │
│  │                                                       │   │
│  │       ■ Claude Code    ■ Gemini                       │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**交互说明：**
- 统计卡片：点击可跳转到对应的详情页
- Live Sessions 列表：点击某个 Session 进入会话详情
- 进度条：来自 Agent 的 TodoWrite 数据，实时更新
- 状态标识：● 运行中（绿色）、○ 空闲（灰色）、✓ 已完成（蓝色）、✕ 错误（红色）

---

### 2.2 Session Detail（会话详情页）

点击某个 Session 后进入，展示该 Agent 会话的完整信息。

```
┌─ Session Detail ─────────────────────────────────────────────┐
│                                                              │
│  ← Back to Dashboard                                        │
│                                                              │
│  claude-code · session-a1b2c3                                │
│  Project: ~/my-project    Started: 14:30    Duration: 23m    │
│                                                              │
│  ┌─ Status ─────┐ ┌─ Progress ──────────┐ ┌─ Tokens ─────┐  │
│  │  ● Running   │ │ ████████░░░░  5/8   │ │ In:  3,200   │  │
│  │  Editing file│ │                     │ │ Out: 1,850   │  │
│  └──────────────┘ └─────────────────────┘ └──────────────┘  │
│                                                              │
│  ┌─ Task Progress ───────────────────────────────────────┐   │
│  │  ✓ Set up project scaffolding                         │   │
│  │  ✓ Create database models                             │   │
│  │  ✓ Implement API endpoints                            │   │
│  │  ✓ Write unit tests                                   │   │
│  │  → Add error handling          (in progress)          │   │
│  │  ○ Update documentation                               │   │
│  │  ○ Run final tests                                    │   │
│  │  ○ Commit and push                                    │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ Event Timeline ──────────────────────────────────────┐   │
│  │                                                       │   │
│  │  Filter: [All ▾]  [Tool Calls ▾]  [Search...]        │   │
│  │                                                       │   │
│  │  14:52:30  ▶ Tool Call: Edit                          │   │
│  │            File: src/handlers/auth.ts                 │   │
│  │            Lines: 45-67 · Duration: 1.2s              │   │
│  │            [Expand ▾]                                 │   │
│  │                                                       │   │
│  │  14:52:28  💭 Thinking                                │   │
│  │            "Now I need to add error handling..."       │   │
│  │            Tokens: 320 in / 180 out · 2.1s            │   │
│  │                                                       │   │
│  │  14:52:15  ▶ Tool Call: Grep                          │   │
│  │            Pattern: "handleAuth" · 3 matches          │   │
│  │            Duration: 0.3s                             │   │
│  │            [Expand ▾]                                 │   │
│  │                                                       │   │
│  │  14:51:50  ▶ Tool Call: Read                          │   │
│  │            File: src/handlers/auth.ts                 │   │
│  │            Lines: 1-120 · Duration: 0.1s              │   │
│  │            [Expand ▾]                                 │   │
│  │                                                       │   │
│  │  14:51:48  💭 Thinking                                │   │
│  │            "Let me look at the auth handler..."       │   │
│  │            Tokens: 150 in / 95 out · 1.5s             │   │
│  │                                                       │   │
│  │         ··· Load more ···                             │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ Tool Usage Breakdown ────────────────────────────────┐   │
│  │                                                       │   │
│  │  Edit   ████████████████████  18 calls                │   │
│  │  Read   ████████████████     15 calls                 │   │
│  │  Bash   ████████             8 calls                  │   │
│  │  Grep   ██████               6 calls                  │   │
│  │  Glob   ████                 4 calls                  │   │
│  │  Write  ██                   2 calls                  │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**交互说明：**
- Task Progress：实时同步 Agent 的 TodoWrite 状态，当前任务高亮
- Event Timeline：
  - 默认折叠，点击 `[Expand]` 查看完整输入/输出
  - 支持按事件类型过滤（Thinking / Tool Call / Error / Message）
  - 支持关键字搜索
  - 自动滚动到最新事件（可锁定暂停）
- Tool Usage Breakdown：水平柱状图，直观展示工具使用分布

---

### 2.3 Analytics（分析页）

汇总统计数据，帮助用户了解 Agent 使用趋势。

```
┌─ Analytics ──────────────────────────────────────────────────┐
│                                                              │
│  Period: [Last 7 days ▾]    Agent: [All ▾]                   │
│                                                              │
│  ┌─ Token Usage Trend ───────────────────────────────────┐   │
│  │                                                       │   │
│  │  15k│            *                                    │   │
│  │     │      *    / \    *                               │   │
│  │  10k│     / \  /   \  / \                              │   │
│  │     │    /   \/     \/   \   *                         │   │
│  │   5k│   /                 \ / \                        │   │
│  │     │  *                   *   *                       │   │
│  │   0 │──────────────────────────────                   │   │
│  │      Mon  Tue  Wed  Thu  Fri  Sat  Sun                │   │
│  │      ── Input tokens   -- Output tokens               │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ Cost Breakdown ──────┐ ┌─ Agent Comparison ──────────┐   │
│  │                       │ │                             │   │
│  │  This week: $2.45     │ │  Claude Code   ████████ 75% │   │
│  │  Last week: $1.80     │ │  Gemini        ███      25% │   │
│  │  Change:    +36%      │ │                             │   │
│  │                       │ │  Sessions: 24 vs 8          │   │
│  │  ┌─────────────┐     │ │  Avg tokens: 5.2k vs 3.8k   │   │
│  │  │ Claude ███  │     │ │                             │   │
│  │  │ Gemini █    │     │ │                             │   │
│  │  └─────────────┘     │ │                             │   │
│  └───────────────────────┘ └─────────────────────────────┘   │
│                                                              │
│  ┌─ Session History ─────────────────────────────────────┐   │
│  │                                                       │   │
│  │  Date        Agent        Duration  Tokens   Cost     │   │
│  │  ─────────────────────────────────────────────────    │   │
│  │  Mar 3 14:30 claude-code  23m       5,050    $0.15    │   │
│  │  Mar 3 11:15 claude-code  45m       12,300   $0.37    │   │
│  │  Mar 3 09:00 gemini       12m       3,800    $0.08    │   │
│  │  Mar 2 16:45 claude-code  1h 10m    18,500   $0.55    │   │
│  │  Mar 2 14:00 claude-code  30m       8,200    $0.25    │   │
│  │  ··· Show more ···                                    │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**交互说明：**
- 时间范围选择器：支持 Today / 7 days / 30 days / Custom
- Agent 筛选器：可选 All / Claude Code / Gemini
- Session History 表格：点击行跳转到 Session Detail
- 费用变化：显示环比增幅，涨跌使用红绿色区分

---

## 3. 交互状态机

### 3.1 Agent 状态流转

```
                    ┌──────────┐
         ┌─────────│  Created  │
         │         └────┬─────┘
         │              │ session start
         │              ▼
         │         ┌──────────┐
         │    ┌───▶│ Thinking │◀───┐
         │    │    └────┬─────┘    │
         │    │         │          │
         │    │         ▼          │
         │    │  ┌─────────────┐   │
         │    │  │ Tool Calling│───┘
         │    │  └──────┬──────┘
         │    │         │ needs user input
         │    │         ▼
         │    │  ┌──────────────┐
         │    └──│Waiting User  │
         │       └──────┬───────┘
         │              │
         │    ┌─────────┴─────────┐
         │    ▼                   ▼
    ┌──────────┐          ┌──────────┐
    │Completed │          │  Error   │
    └──────────┘          └──────────┘
```

### 3.2 面板状态说明

| 状态 | 颜色 | 图标 | 说明 |
|------|------|------|------|
| Thinking | 蓝色脉冲 | 💭 | Agent 正在思考/推理 |
| Tool Calling | 绿色 | ▶ | Agent 正在执行工具调用 |
| Waiting User | 黄色 | ⏸ | 等待用户输入或审批 |
| Idle | 灰色 | ○ | 会话处于空闲状态 |
| Completed | 蓝色 | ✓ | 会话已正常结束 |
| Error | 红色 | ✕ | 会话出现错误 |

---

## 4. 关键交互细节

### 4.1 实时更新机制
- WebSocket 推送新事件，Timeline 自动追加
- 当用户正在浏览历史记录（向上滚动），暂停自动滚动，底部显示提示："↓ New events (3)"，点击即可跳转到最新

### 4.2 事件展开/折叠
```
┌─ 折叠状态 ────────────────────────────────────────┐
│  14:52:30  ▶ Edit · src/handlers/auth.ts · 1.2s   │
│                                        [Expand ▾]  │
└────────────────────────────────────────────────────┘

┌─ 展开状态 ────────────────────────────────────────┐
│  14:52:30  ▶ Edit · src/handlers/auth.ts · 1.2s   │
│                                      [Collapse ▴]  │
│  ┌─ Input ──────────────────────────────────────┐  │
│  │  file: src/handlers/auth.ts                  │  │
│  │  old_string: "function handleAuth() {"       │  │
│  │  new_string: "async function handleAuth() {" │  │
│  └──────────────────────────────────────────────┘  │
│  ┌─ Output ─────────────────────────────────────┐  │
│  │  ✓ File edited successfully                  │  │
│  └──────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────┘
```

### 4.3 多 Agent 切换
- Dashboard 页面的 Session 列表通过不同图标/颜色区分 Agent 类型
- Claude Code: 紫色标识
- Gemini: 蓝色标识
- 筛选器可按 Agent 类型过滤

### 4.4 响应式设计
- 桌面端（>1200px）：左侧导航 + 右侧内容
- 平板端（768-1200px）：导航收缩为图标，内容区自适应
- 移动端（<768px）：底部 Tab 导航，内容区全屏

---

## 5. 配色方案

### Light Mode
| 元素 | 颜色 |
|------|------|
| 背景 | `#FAFAFA` |
| 卡片 | `#FFFFFF` |
| 主色 | `#6366F1` (Indigo) |
| 成功 | `#22C55E` |
| 警告 | `#EAB308` |
| 错误 | `#EF4444` |
| 文字 | `#1F2937` |

### Dark Mode
| 元素 | 颜色 |
|------|------|
| 背景 | `#0F172A` |
| 卡片 | `#1E293B` |
| 主色 | `#818CF8` |
| 成功 | `#4ADE80` |
| 警告 | `#FACC15` |
| 错误 | `#F87171` |
| 文字 | `#F1F5F9` |

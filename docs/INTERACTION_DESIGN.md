# Agent Watch Tower - 交互设计

## 1. 产品形态：Menu Bar + 可 Pin 悬浮窗

应用常驻 macOS 菜单栏，提供两种互相切换的展示模式：

```
模式 A: Menu Bar Popover            模式 B: Floating Panel (Pinned)
─────────────────────               ─────────────────────────────
                                    ┌─ Agent Watch Tower ─── □ ✕┐
  🗼 ← 菜单栏图标                    │                          │
   │                                │   (面板内容相同)          │
   ▼ 点击展开                       │   可拖拽到任意位置         │
 ┌──────────────┐                   │   always-on-top           │
 │   Popover    │   ──  📌 Pin ──▶  │                          │
 │   跟随图标   │   ◀── Unpin ──   │                          │
 │   自动收起   │                   └──────────────────────────┘
 └──────────────┘                    独立窗口，不自动收起
```

---

## 2. Menu Bar 图标状态

菜单栏图标根据 Agent 状态实时变化：

```
 正常空闲        有 Agent 运行中      有错误发生
 ┌───┐          ┌───┐               ┌───┐
 │🗼 │          │🗼•│ (脉冲动画)     │🗼!│ (红色感叹号)
 └───┘          └───┘               └───┘

 可选：图标右侧显示活跃数
 ┌──────┐
 │🗼 2  │  ← 2 个 Agent 正在运行
 └──────┘
```

| 图标状态 | 含义 | 视觉表现 |
|---------|------|---------|
| 静态 🗼 | 无活跃 Agent | 默认灰色图标 |
| 脉冲 🗼• | 有 Agent 运行中 | 图标带呼吸动画 |
| 警告 🗼! | 有 Agent 出错 | 图标叠加红点 |

---

## 3. 简要面板（核心视图）

### 3.1 面板整体布局

面板尺寸约 **320 x 420pt**，紧凑但信息密度高。

```
┌─ Agent Watch Tower ──────────── 📌 ─┐
│                                      │
│  Today: 15.2k tokens · $0.46        │
│                                      │
├──────────────────────────────────────┤
│                                      │
│  ● claude-code         ⏱ 23m        │
│    my-project/                       │
│    ▶ Editing auth.ts                 │
│    ████████████░░░░░░  5/8 tasks     │
│    Tokens: 3.2k in · 1.8k out       │
│                                      │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│                                      │
│  ● claude-code         ⏱ 8m         │
│    api-server/                       │
│    💭 Thinking...                    │
│    ██████░░░░░░░░░░░░  2/10 tasks    │
│    Tokens: 1.1k in · 0.6k out       │
│                                      │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│                                      │
│  ○ claude-code         ⏱ 45m        │
│    docs/                             │
│    ⏸ Waiting for user               │
│    ████████████████░░  8/10 tasks    │
│    Tokens: 8.5k in · 4.2k out       │
│                                      │
├──────────────────────────────────────┤
│  [⚙ Settings]              [📊 More]│
└──────────────────────────────────────┘
```

### 3.2 会话卡片设计

每个 Agent 会话以卡片形式展示：

```
┌──────────────────────────────────────┐
│  ●  claude-code              ⏱ 23m  │
│  ↑  ↑                          ↑    │
│  │  Agent 类型               持续时间│
│  状态指示灯(颜色)                    │
│                                      │
│  my-project/                         │
│  ↑ 项目目录（取最后一级目录名）       │
│                                      │
│  ▶ Editing auth.ts                   │
│  ↑ 当前动作（实时更新）              │
│                                      │
│  ████████████░░░░░░  5/8 tasks       │
│  ↑ 任务进度条（来自 TodoWrite）      │
│                                      │
│  Tokens: 3.2k in · 1.8k out         │
│  ↑ 本次会话 Token 消耗               │
└──────────────────────────────────────┘
```

### 3.3 状态指示灯

| 状态 | 颜色 | 符号 | 动画 |
|------|------|------|------|
| Running - Thinking | 蓝色 | ● | 慢速脉冲 |
| Running - Tool Call | 绿色 | ● | 快速脉冲 |
| Waiting for User | 黄色 | ○ | 静态 |
| Idle | 灰色 | ○ | 静态 |
| Completed | 蓝色 | ✓ | 静态 |
| Error | 红色 | ✕ | 静态 |

---

## 4. Pin / Unpin 交互

### 4.1 Pin 切换流程

```
         Menu Bar Popover                    Floating Panel
    ┌──────────────────────┐           ┌──────────────────────┐
    │  Title bar     [📌]  │           │  Title bar  [📌] [✕] │
    │                      │           │                      │
    │   (面板内容)         │  点击📌   │   (面板内容相同)     │
    │                      │ ────────▶ │                      │
    │                      │           │  ● 窗口脱离菜单栏    │
    │                      │           │  ● always-on-top     │
    └──────────────────────┘           │  ● 可拖拽移动        │
    特征：                              │  ● 可调整大小        │
    - 点击面板外区域自动收起            └──────────────────────┘
    - 箭头指向菜单栏图标                特征：
    - 不可移动/缩放                     - 不会自动收起
                                        - 再次点📌 回到 Popover 模式
```

### 4.2 Pin 状态下的窗口行为

- **always-on-top**：使用 `NSPanel` + `NSWindow.Level.floating`
- **可拖拽**：按住标题栏拖动到任意位置
- **可缩放**：支持拖拽边角调整大小（最小 280x300，最大 480x800）
- **记忆位置**：下次打开时恢复上次 Pin 位置和大小
- **点击穿透**：面板不抢占焦点，不影响当前活跃窗口的键盘输入

### 4.3 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘ + Shift + A` | 呼出/收起面板 (全局) |
| `⌘ + P` | Pin/Unpin 切换 (面板内) |
| `Esc` | 收起面板 (Popover 模式) |

---

## 5. 详情展开视图

点击会话卡片后，面板内展开该会话的详细信息（push 导航）。

```
┌─ Agent Watch Tower ──────────── 📌 ─┐
│                                      │
│  ← Back                             │
│                                      │
│  ● claude-code · session-a1b2       │
│    my-project/ · 23m · Running       │
│                                      │
├─ Progress ───────────────────────────┤
│  ✓ Set up project scaffolding        │
│  ✓ Create database models            │
│  ✓ Implement API endpoints           │
│  ✓ Write unit tests                  │
│  → Add error handling  (current)     │
│  ○ Update documentation              │
│  ○ Run final tests                   │
│  ○ Commit and push                   │
│                                      │
├─ Recent Events ──────────────────────┤
│                                      │
│  14:52:30  ▶ Edit                    │
│            src/handlers/auth.ts      │
│            1.2s                       │
│                                      │
│  14:52:28  💭 Think   2.1s           │
│            320 in / 180 out          │
│                                      │
│  14:52:15  ▶ Grep                    │
│            "handleAuth" · 3 matches  │
│            0.3s                       │
│                                      │
│  14:51:50  ▶ Read                    │
│            src/handlers/auth.ts      │
│            0.1s                       │
│                                      │
│          ··· Load more ···           │
│                                      │
├─ Tool Usage ─────────────────────────┤
│  Edit  ████████████████████  18      │
│  Read  ████████████████     15       │
│  Bash  ████████             8        │
│  Grep  ██████               6        │
│                                      │
├─ Tokens ─────────────────────────────┤
│  Input:  3,200    Output: 1,850      │
│  Est. Cost: $0.15                    │
│                                      │
└──────────────────────────────────────┘
```

**交互说明：**
- 点击 `← Back` 返回会话列表
- Event 列表支持上滑加载更多历史事件
- 新事件自动追加到顶部，带淡入动画
- 点击某条 Event 可展开查看完整输入/输出内容

---

## 6. 事件展开/折叠

```
┌─ 折叠（默认） ────────────────────────┐
│  14:52:30  ▶ Edit                     │
│            src/handlers/auth.ts  1.2s │
└───────────────────────────────────────┘
               │ 点击
               ▼
┌─ 展开 ────────────────────────────────┐
│  14:52:30  ▶ Edit                     │
│            src/handlers/auth.ts  1.2s │
│                                       │
│  ┌─ Input ─────────────────────────┐  │
│  │ file: src/handlers/auth.ts      │  │
│  │ old: "function handleAuth() {"  │  │
│  │ new: "async function handle..." │  │
│  └─────────────────────────────────┘  │
│  ┌─ Output ────────────────────────┐  │
│  │ ✓ File edited successfully      │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

Input/Output 区域使用 macOS 原生代码样式（等宽字体 + 轻微背景色区分）。

---

## 7. Settings 窗口

独立的 macOS 标准设置窗口（非面板内），通过面板底部 ⚙ 按钮或 `⌘ + ,` 打开。

```
┌─ Settings ───────────────────────────────┐
│                                          │
│  [General]  [Agents]  [Display]          │
│                                          │
│  ─── General ───────────────────────     │
│                                          │
│  Launch at login          [✓]            │
│  Global shortcut    [⌘ + Shift + A]      │
│  Show in Dock             [ ]            │
│                                          │
│  ─── Data ──────────────────────────     │
│                                          │
│  Event retention     [30 days ▾]         │
│  Database location   ~/Library/...       │
│  [Clear history...]                      │
│                                          │
│  ─── Agents ────────────────────────     │
│                                          │
│  Claude Code                             │
│    Status: ● Connected                   │
│    Hook port: 19280                      │
│    [Install Hooks]  [Test Connection]    │
│                                          │
│  Gemini (Coming Soon)                    │
│    Status: ○ Not configured              │
│                                          │
└──────────────────────────────────────────┘
```

---

## 8. 状态流转与动画

### 8.1 Agent 状态机

```
                  ┌──────────┐
       ┌──────── │  Created  │
       │         └─────┬─────┘
       │               │ hook: first event
       │               ▼
       │         ┌──────────┐
       │    ┌───▶│ Thinking │◀────┐
       │    │    └─────┬────┘     │
       │    │          │          │
       │    │          ▼          │
       │    │   ┌─────────────┐   │
       │    │   │ Tool Calling│───┘
       │    │   └──────┬──────┘
       │    │          │ needs user input
       │    │          ▼
       │    │   ┌──────────────┐
       │    └── │Waiting User  │
       │        └──────┬───────┘
       │               │
       │     ┌─────────┴─────────┐
       │     ▼                   ▼
  ┌────┴─────┐           ┌──────────┐
  │Completed │           │  Error   │
  └──────────┘           └──────────┘
```

### 8.2 动画设计

| 场景 | 动画 | 时长 |
|------|------|------|
| 新会话出现 | 卡片从上方滑入 + 淡入 | 300ms |
| 会话结束 | 卡片淡出 + 高度收缩 | 250ms |
| 状态切换 | 指示灯颜色渐变 | 200ms |
| 进度条更新 | 宽度平滑过渡 | 150ms |
| 新事件追加 | 从顶部滑入 | 200ms |
| Pin/Unpin | 弹簧动画切换窗口形态 | 400ms |
| 详情展开 | Push 导航滑入 | 300ms |

所有动画使用 SwiftUI 内建的 `.animation(.spring())` 或 `.animation(.easeInOut)`。

---

## 9. 深色/浅色模式

自动跟随 macOS 系统设置，使用 SwiftUI 原生语义色。

### 浅色模式
```
┌──────────────────────────────┐
│  背景:  .background          │  ← 系统白/浅灰
│  卡片:  .secondaryBackground │  ← 纯白
│  文字:  .primary             │  ← 黑色
│  次要:  .secondary           │  ← 灰色
│  强调:  .accentColor         │  ← 系统蓝/自定义紫
└──────────────────────────────┘
```

### 深色模式
```
┌──────────────────────────────┐
│  背景:  .background          │  ← 深灰
│  卡片:  .secondaryBackground │  ← 稍亮灰
│  文字:  .primary             │  ← 白色
│  次要:  .secondary           │  ← 浅灰
│  强调:  .accentColor         │  ← 系统蓝/自定义紫
└──────────────────────────────┘
```

Agent 类型标识色不随主题变化：
- Claude Code: `#8B5CF6` (紫色)
- Gemini: `#2563EB` (蓝色)

---

## 10. 悬浮窗尺寸规格

| 属性 | 值 |
|------|-----|
| Popover 默认宽度 | 320pt |
| Popover 默认高度 | 自适应内容，max 500pt |
| Pin 最小尺寸 | 280 x 300pt |
| Pin 最大尺寸 | 480 x 800pt |
| Pin 默认尺寸 | 320 x 420pt |
| 卡片间距 | 8pt |
| 内边距 | 12pt |
| 圆角 | 10pt (窗口) / 8pt (卡片) |

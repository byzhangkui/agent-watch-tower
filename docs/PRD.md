# Agent Watch Tower - 产品需求文档 (PRD)

## 1. 概述

### 1.1 产品定位
Agent Watch Tower 是一个 AI Agent 工作状态监控面板，帮助开发者实时观测、管理和分析 AI Agent 的运行状态。首期支持 Claude Code，后续扩展 Gemini 等更多 Agent。

### 1.2 目标用户
- 使用 AI Agent 辅助开发的工程师
- 管理多个 Agent 实例的团队 Lead
- 需要追踪 Agent 使用成本的项目管理者

### 1.3 核心价值
| 痛点 | 解决方案 |
|------|----------|
| Agent 在后台运行，不知道进度 | 实时状态面板，一目了然 |
| 多个 Agent 同时工作，切换混乱 | 统一监控视图，集中管理 |
| Token 消耗不透明 | 用量统计与成本分析 |
| 任务失败难以排查 | 完整的操作日志与错误追踪 |

---

## 2. 功能规划

### 2.1 Phase 1 — Claude Code 监控（MVP）

#### 2.1.1 Agent 会话管理
- 展示所有活跃的 Claude Code 会话列表
- 每个会话显示：会话 ID、启动时间、当前状态、所在项目目录
- 支持按状态过滤（运行中 / 空闲 / 已结束 / 错误）

#### 2.1.2 实时状态监控
- **工作状态**：Thinking → Tool Calling → Waiting for User → Idle → Error
- **当前任务**：展示 Agent 正在处理的任务描述
- **工具调用**：实时显示 Agent 调用了哪些工具（Read, Edit, Bash, Grep 等）
- **进度追踪**：如果 Agent 使用了 TodoWrite，展示任务完成进度

#### 2.1.3 操作日志
- 按时间线展示 Agent 的完整操作历史
- 每条日志包含：时间戳、操作类型、输入摘要、输出摘要、耗时
- 支持展开查看完整的输入/输出内容
- 支持按工具类型筛选

#### 2.1.4 资源消耗
- Token 使用量（输入/输出分开统计）
- API 调用次数
- 预估费用（基于模型定价）
- 会话维度和日/周/月维度的统计

### 2.2 Phase 2 — 多 Agent 支持

#### 2.2.1 Gemini Agent 接入
- 接入 Gemini Agent 的状态监控
- 统一的数据模型抽象，适配不同 Agent 的状态格式

#### 2.2.2 跨 Agent 对比
- 同一任务在不同 Agent 上的表现对比
- Token 消耗对比、完成速度对比

### 2.3 Phase 3 — 高级功能

- 告警规则：Token 超限、长时间无响应、错误率过高时通知
- 历史趋势分析：使用量趋势图、效率变化曲线
- 团队视图：多人多 Agent 的聚合监控

---

## 3. 技术架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────┐
│                  Web Dashboard                   │
│               (React + TypeScript)               │
└──────────────────────┬──────────────────────────┘
                       │ WebSocket / REST
┌──────────────────────┴──────────────────────────┐
│                  Backend Server                   │
│                (Node.js + Express)                │
└───────┬──────────────────────────────┬──────────┘
        │                              │
┌───────┴────────┐           ┌────────┴─────────┐
│  Claude Code   │           │   Gemini Agent   │
│   Adapter      │           │    Adapter       │
│  (Hooks/CLI)   │           │   (API)          │
└────────────────┘           └──────────────────┘
```

### 3.2 数据采集方案

#### Claude Code
- **方案 A（推荐）**：利用 Claude Code 的 Hooks 机制，在关键事件（tool call、message 等）触发时上报数据
- **方案 B**：解析 Claude Code 的日志文件，被动采集数据
- **方案 C**：通过 Claude Code SDK（Agent SDK）直接集成

#### Gemini
- 通过 Gemini API 的调用封装层采集数据
- 或通过 Gemini 提供的监控/日志接口获取

### 3.3 数据模型

```typescript
// 通用 Agent 会话
interface AgentSession {
  id: string;
  agentType: 'claude-code' | 'gemini' | string;
  status: 'running' | 'idle' | 'completed' | 'error';
  projectDir: string;
  startedAt: Date;
  endedAt?: Date;
  metadata: Record<string, unknown>;
}

// 通用 Agent 事件
interface AgentEvent {
  id: string;
  sessionId: string;
  timestamp: Date;
  type: 'thinking' | 'tool_call' | 'tool_result' | 'message' | 'error';
  data: {
    toolName?: string;
    input?: string;
    output?: string;
    tokensUsed?: { input: number; output: number };
    durationMs?: number;
  };
}

// 资源用量统计
interface UsageStats {
  sessionId: string;
  totalTokens: { input: number; output: number };
  totalApiCalls: number;
  estimatedCost: number;
  toolUsageBreakdown: Record<string, number>;
}
```

### 3.4 技术选型

| 层级 | 选型 | 理由 |
|------|------|------|
| 前端框架 | React + TypeScript | 生态成熟，组件丰富 |
| UI 组件库 | Shadcn/ui + Tailwind CSS | 轻量灵活，样式可控 |
| 状态管理 | Zustand | 轻量，适合中等复杂度 |
| 实时通信 | WebSocket (Socket.io) | 低延迟，双向通信 |
| 后端框架 | Node.js + Express | 与前端技术栈统一 |
| 数据存储 | SQLite (开发) / PostgreSQL (生产) | 从轻量起步，可扩展 |
| 构建工具 | Vite | 快速，现代 |

---

## 4. 非功能需求

- **性能**：面板数据刷新延迟 < 1s，支持同时监控 10+ 个 Agent 会话
- **可扩展**：新增 Agent 类型只需实现 Adapter 接口
- **易部署**：支持 `npm run dev` 一键启动本地开发
- **数据安全**：敏感信息（API Key 等）不展示在面板上

---

## 5. 里程碑

| 阶段 | 内容 | 预期产出 |
|------|------|----------|
| M1 | 项目脚手架 + Claude Code 数据采集 | 能采集并存储 Claude Code 事件 |
| M2 | 监控面板 MVP | 实时展示 Claude Code 工作状态 |
| M3 | Gemini 接入 | 支持 Gemini Agent 监控 |
| M4 | 高级分析功能 | 告警、趋势、团队视图 |

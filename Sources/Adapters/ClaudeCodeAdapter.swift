import Foundation

struct ClaudeCodeAdapter: AgentAdapter {
    let agentType: AgentType = .claudeCode

    func describeAction(from payload: HookPayload) -> String? {
        // Non-tool lifecycle events
        if payload.toolName == nil {
            switch payload.hookEventName {
            case "UserPromptSubmit":
                return "User Input"
            case "SessionStart":
                let src = payload.source ?? "startup"
                return src == "resume" ? "Session Resumed" : "Session Started"
            case "Stop":
                return "Session Ended"
            case "Notification":
                return "Notification"
            case "SubagentStart":
                return "Agent Started: \(payload.agentName ?? "subagent")"
            case "SubagentStop":
                return "Agent Stopped: \(payload.agentName ?? "subagent")"
            default:
                return payload.hookEventName
            }
        }

        let toolName = payload.toolName!
        let input = payload.toolInput

        switch toolName {
        case "Edit":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Editing \(file ?? "file")"
        case "Write":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Writing \(file ?? "file")"
        case "Read":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Reading \(file ?? "file")"
        case "Bash":
            let cmd = input?.command.map { String($0.prefix(40)) } ?? input?.description
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
        case "TodoWrite":
            return "Updating tasks"
        case "WebSearch":
            return "Searching web"
        case "WebFetch":
            return "Fetching web content"
        default:
            return toolName
        }
    }

    func parseEvent(from payload: HookPayload) -> AgentEvent? {
        let eventType: EventType
        switch payload.hookEventName {
        case "PreToolUse":
            eventType = .toolCall
        case "PostToolUse":
            eventType = .toolResult
        case "Stop", "Notification", "SessionStart", "UserPromptSubmit":
            eventType = .message
        case "SubagentStart":
            eventType = .subagentStart
        case "SubagentStop":
            eventType = .subagentStop
        default:
            eventType = .message
        }

        // Encode the payload for raw storage
        let rawJson = try? JSONEncoder().encode(payload)
        let rawString = rawJson.flatMap { String(data: $0, encoding: .utf8) }

        return AgentEvent(
            id: payload.toolUseId ?? UUID().uuidString,
            sessionId: payload.sessionId,
            timestamp: Date().timeIntervalSince1970,
            eventType: eventType,
            toolName: payload.toolName,
            inputSummary: describeAction(from: payload),
            outputSummary: payload.hookEventName == "PostToolUse"
                ? payload.toolResponse?.summary
                : nil,
            rawPayload: rawString
        )
    }

    func updateSession(from payload: HookPayload, existing: AgentSession?) -> AgentSession {
        let now = Date().timeIntervalSince1970

        if var session = existing {
            switch payload.hookEventName {
            case "PreToolUse":
                session.status = .running
                session.currentAction = describeAction(from: payload)
                session.updatedAt = now

            case "PostToolUse":
                session.status = .running
                session.currentAction = nil  // Clear after tool finishes; next PreToolUse will set it
                session.updatedAt = now
                // Check if it's a TodoWrite to update progress
                if payload.toolName == "TodoWrite" {
                    updateTodoProgress(from: payload, session: &session)
                }

            case "Stop":
                session.status = .completed
                session.endedAt = now
                session.currentAction = nil
                session.updatedAt = now

            case "Notification":
                session.updatedAt = now

            case "SubagentStart":
                session.currentAction = "Agent: \(payload.agentName ?? "subagent")"
                session.updatedAt = now

            case "SubagentStop":
                session.updatedAt = now

            case "UserPromptSubmit":
                session.status = .running
                session.currentAction = nil
                session.updatedAt = now

            case "SessionStart":
                session.status = .running
                if let model = payload.model {
                    session.model = model
                }
                session.updatedAt = now

            default:
                session.updatedAt = now
            }

            return session
        } else {
            return AgentSession.create(
                id: payload.sessionId,
                agentType: .claudeCode,
                projectDir: payload.cwd ?? "Unknown Directory",
                model: payload.model
            )
        }
    }

    // MARK: - Private

    private func updateTodoProgress(from payload: HookPayload, session: inout AgentSession) {
        // TodoWrite payload contains the full todo list in toolInput
        // We parse it to extract completed/total counts
        guard let rawPayload = try? JSONEncoder().encode(payload),
              let json = try? JSONSerialization.jsonObject(with: rawPayload) as? [String: Any],
              let toolInput = json["tool_input"] as? [String: Any],
              let todos = toolInput["todos"] as? [[String: Any]] else {
            return
        }

        let total = todos.count
        let completed = todos.filter { ($0["status"] as? String) == "completed" }.count
        session.todoCompleted = completed
        session.todoTotal = total
    }
}

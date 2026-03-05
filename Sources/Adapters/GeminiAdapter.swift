import Foundation

struct GeminiAdapter: AgentAdapter {
    let agentType: AgentType = .gemini

    func describeAction(from payload: HookPayload) -> String? {
        // Non-tool lifecycle events
        if payload.toolName == nil {
            switch payload.hookEventName {
            case "SessionStart":
                let src = payload.source ?? "startup"
                return src == "resume" ? "Session Resumed" : "Session Started"
            case "SessionEnd":
                return "Session Ended"
            case "Notification":
                return "Notification"
            case "BeforeAgent":
                return "Agent Started: \(payload.agentName ?? "subagent")"
            case "AfterAgent":
                return "Agent Stopped: \(payload.agentName ?? "subagent")"
            default:
                return payload.hookEventName
            }
        }

        let toolName = payload.toolName!
        let input = payload.toolInput

        switch toolName {
        case "replace":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Replacing text in \(file ?? "file")"
        case "write_file":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Writing \(file ?? "file")"
        case "read_file":
            let file = input?.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
            return "Reading \(file ?? "file")"
        case "run_shell_command":
            let cmd = input?.command.map { String($0.prefix(40)) } ?? input?.description
            return "Running \(cmd ?? "command")..."
        case "grep_search":
            let pattern = input?.pattern ?? ""
            return "Searching \"\(pattern)\""
        case "glob":
            let pattern = input?.pattern ?? input?.glob ?? ""
            return "Finding \(pattern)"
        case "codebase_investigator":
            return "Investigating codebase"
        case "browser_agent":
            return "Browsing web"
        case "cli_help":
            return "Checking CLI Help"
        default:
            return toolName
        }
    }

    func parseEvent(from payload: HookPayload) -> AgentEvent? {
        let eventType: EventType
        switch payload.hookEventName {
        case "BeforeTool":
            eventType = .toolCall
        case "AfterTool":
            eventType = .toolResult
        case "SessionEnd", "Notification", "SessionStart":
            eventType = .message
        case "BeforeAgent":
            eventType = .subagentStart
        case "AfterAgent":
            eventType = .subagentStop
        default:
            eventType = .message
        }

        // Encode the payload for raw storage
        let rawJson = try? JSONEncoder().encode(payload)
        let rawString = rawJson.flatMap { String(data: $0, encoding: .utf8) }

        // Use toolUseId with event-type suffix if available, else generate UUID
        let eventId: String
        if let toolUseId = payload.toolUseId ?? payload.id {
            let suffix = payload.hookEventName == "AfterTool" ? "-post" : "-pre"
            eventId = toolUseId + suffix
        } else {
            eventId = UUID().uuidString
        }

        return AgentEvent(
            id: eventId,
            sessionId: payload.sessionId,
            timestamp: payload.timestampDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            eventType: eventType,
            toolName: payload.toolName,
            inputSummary: describeAction(from: payload),
            outputSummary: payload.hookEventName == "AfterTool"
                ? payload.toolResponse?.summary
                : nil,
            rawPayload: rawString
        )
    }

    func updateSession(from payload: HookPayload, existing: AgentSession?) -> AgentSession {
        let now = payload.timestampDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

        if var session = existing {
            switch payload.hookEventName {
            case "BeforeTool":
                session.status = .running
                session.currentAction = describeAction(from: payload)
                session.updatedAt = now

            case "AfterTool":
                session.status = .thinking
                session.currentAction = "Thinking..."
                session.updatedAt = now

            case "SessionEnd":
                session.status = payload.reason == "error" ? .error : .completed
                session.endedAt = now
                session.currentAction = nil
                session.updatedAt = now

            case "Notification":
                session.updatedAt = now

            case "BeforeAgent":
                session.currentAction = "Agent: \(payload.agentName ?? "subagent")"
                session.updatedAt = now

            case "AfterAgent":
                if session.status == .completed || session.status == .error {
                    session.status = .running
                    session.endedAt = nil
                }
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
                agentType: .gemini,
                projectDir: payload.cwd ?? "Unknown Directory",
                model: payload.model
            )
        }
    }
}

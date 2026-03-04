import Foundation

// MARK: - Agent Type

enum AgentType: String, Codable, Hashable {
    case claudeCode = "claude-code"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .claudeCode: "claude-code"
        case .gemini: "gemini"
        }
    }

    var brandColor: String {
        switch self {
        case .claudeCode: "#bf5af2" // Purple
        case .gemini: "#2563EB"
        }
    }
}

// MARK: - Session Status

enum SessionStatus: String, Codable, Hashable {
    case running
    case thinking
    case waitingForUser = "waiting_for_user"
    case idle
    case completed
    case error
}

// MARK: - Event Type

enum EventType: String, Codable, Hashable {
    case toolCall = "tool_call"
    case toolResult = "tool_result"
    case message
    case error
    case subagentStart = "subagent_start"
    case subagentStop = "subagent_stop"
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionDidUpdate = Notification.Name("AgentWatchTower.sessionDidUpdate")
    static let activeSessionsChanged = Notification.Name("AgentWatchTower.activeSessionsChanged")
}

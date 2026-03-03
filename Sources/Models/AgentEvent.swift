import Foundation
import GRDB

struct AgentEvent: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "agent_event"

    var id: String
    var sessionId: String
    var timestamp: Double       // Unix timestamp
    var eventType: EventType
    var toolName: String?
    var inputSummary: String?
    var outputSummary: String?
    var tokensInput: Int?
    var tokensOutput: Int?
    var durationMs: Int?
    var rawPayload: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case timestamp
        case eventType = "event_type"
        case toolName = "tool_name"
        case inputSummary = "input_summary"
        case outputSummary = "output_summary"
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
        case durationMs = "duration_ms"
        case rawPayload = "raw_payload"
    }
}

// MARK: - Computed Properties

extension AgentEvent {
    var date: Date { Date(timeIntervalSince1970: timestamp) }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var durationFormatted: String? {
        guard let ms = durationMs else { return nil }
        if ms < 1000 {
            return String(format: "%.1fs", Double(ms) / 1000)
        }
        return String(format: "%.1fs", Double(ms) / 1000)
    }

    var toolIcon: String {
        switch toolName {
        case "Edit":      return "pencil"
        case "Write":     return "doc.badge.plus"
        case "Read":      return "doc.text"
        case "Bash":      return "terminal"
        case "Grep":      return "magnifyingglass"
        case "Glob":      return "folder.badge.magnifyingglass"
        case "Agent":     return "person.2"
        case "TodoWrite": return "checklist"
        case "WebSearch": return "safari"
        case "WebFetch":  return "arrow.down.circle"
        case nil:
            // Lifecycle events (no tool)
            switch eventType {
            case .message:      return "text.bubble"
            case .subagentStart: return "person.2.badge.plus"
            case .subagentStop:  return "person.2.badge.minus"
            default:            return "circle.dotted"
            }
        default:          return "gear"
        }
    }
}

// MARK: - Factory

extension AgentEvent {
    static func create(
        sessionId: String,
        eventType: EventType,
        toolName: String? = nil,
        inputSummary: String? = nil,
        rawPayload: String? = nil
    ) -> AgentEvent {
        AgentEvent(
            id: UUID().uuidString,
            sessionId: sessionId,
            timestamp: Date().timeIntervalSince1970,
            eventType: eventType,
            toolName: toolName,
            inputSummary: inputSummary,
            rawPayload: rawPayload
        )
    }
}

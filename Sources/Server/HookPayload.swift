import Foundation

/// Claude Code Hook payload received via HTTP POST.
/// The structure varies by hook event type but shares common fields.
struct HookPayload: Codable {
    // Common fields
    let sessionId: String
    let cwd: String
    let hookEventName: String
    let transcriptPath: String?

    // PreToolUse / PostToolUse
    let toolName: String?
    let toolInput: ToolInput?
    let toolResponse: ToolResponse?
    let toolUseId: String?

    // SessionStart
    let source: String?          // "startup", "resume", "clear"
    let model: String?

    // SubagentStart / SubagentStop
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

// MARK: - Tool Input

/// Captures tool inputs across all Claude Code tool types.
/// Uses optional fields since each tool provides different parameters.
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

// MARK: - Tool Response

/// Wraps tool response, which can be a string or complex object.
struct ToolResponse: Codable {
    let rawValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            rawValue = str
        } else if let data = try? container.decode(AnyCodableValue.self) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let jsonData = try? encoder.encode(data) {
                rawValue = String(data: jsonData, encoding: .utf8)
            } else {
                rawValue = nil
            }
        } else {
            rawValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var summary: String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.prefix(200)
        return String(trimmed)
    }
}

// MARK: - AnyCodableValue (for decoding arbitrary JSON)

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let val = try? container.decode(String.self) {
            self = .string(val)
        } else if let val = try? container.decode(Int.self) {
            self = .int(val)
        } else if let val = try? container.decode(Double.self) {
            self = .double(val)
        } else if let val = try? container.decode(Bool.self) {
            self = .bool(val)
        } else if let val = try? container.decode([AnyCodableValue].self) {
            self = .array(val)
        } else if let val = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(val)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .int(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .array(let val): try container.encode(val)
        case .dictionary(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }
}

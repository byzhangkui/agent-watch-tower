import Foundation

/// Parses Claude Code transcript.jsonl files to extract data
/// not available from hook events (stop_reason, token usage).
struct TranscriptParser {

    struct TranscriptEntry: Codable {
        let type: String
        let message: MessageContent?
    }

    struct MessageContent: Codable {
        let role: String?
        let content: [ContentBlock]?
        let stopReason: String?
        let usage: UsageInfo?

        enum CodingKeys: String, CodingKey {
            case role, content
            case stopReason = "stop_reason"
            case usage
        }
    }

    struct UsageInfo: Codable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    struct ContentBlock: Codable {
        let type: String
        let name: String?
    }

    struct ParseResult {
        let lastStopReason: String?
        let totalInputTokens: Int
        let totalOutputTokens: Int
        let toolCallCount: Int
    }

    /// Parse a transcript JSONL file, reading only the last N lines for performance.
    func parse(_ path: String, tailLines: Int = 50) -> ParseResult? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.split(separator: "\n").suffix(tailLines)

        var lastStopReason: String?
        var totalInput = 0
        var totalOutput = 0
        var toolCalls = 0

        let decoder = JSONDecoder()

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(TranscriptEntry.self, from: lineData) else {
                continue
            }

            if let msg = entry.message {
                if let usage = msg.usage {
                    totalInput += usage.inputTokens
                    totalOutput += usage.outputTokens
                }
                if entry.type == "assistant", let reason = msg.stopReason {
                    lastStopReason = reason
                }
                toolCalls += msg.content?
                    .filter { $0.type == "tool_use" }.count ?? 0
            }
        }

        return ParseResult(
            lastStopReason: lastStopReason,
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            toolCallCount: toolCalls
        )
    }
}

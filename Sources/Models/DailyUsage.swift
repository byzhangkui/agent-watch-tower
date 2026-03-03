import Foundation
import GRDB

struct DailyUsage: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "daily_usage"

    var date: String            // "YYYY-MM-DD"
    var agentType: String
    var totalSessions: Int
    var tokensInput: Int
    var tokensOutput: Int
    var apiCalls: Int
    var estimatedCost: Double

    enum CodingKeys: String, CodingKey {
        case date
        case agentType = "agent_type"
        case totalSessions = "total_sessions"
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
        case apiCalls = "api_calls"
        case estimatedCost = "estimated_cost"
    }
}

extension DailyUsage {
    var totalTokens: Int { tokensInput + tokensOutput }

    var costFormatted: String {
        String(format: "$%.2f", estimatedCost)
    }

    var tokensFormatted: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fk", Double(total) / 1_000)
        }
        return "\(total)"
    }

    static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

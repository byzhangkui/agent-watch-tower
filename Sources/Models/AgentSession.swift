import Foundation
import GRDB

struct AgentSession: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "agent_session"

    var id: String
    var agentType: AgentType
    var status: SessionStatus
    var projectDir: String
    var currentAction: String?
    var todoCompleted: Int?
    var todoTotal: Int?
    var model: String?
    var startedAt: Double      // Unix timestamp
    var endedAt: Double?
    var updatedAt: Double
    var tokensInput: Int?
    var tokensOutput: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case agentType = "agent_type"
        case status
        case projectDir = "project_dir"
        case currentAction = "current_action"
        case todoCompleted = "todo_completed"
        case todoTotal = "todo_total"
        case model
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case updatedAt = "updated_at"
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
    }
}

// MARK: - Computed Properties

extension AgentSession {
    var startDate: Date { Date(timeIntervalSince1970: startedAt) }
    var endDate: Date? { endedAt.map { Date(timeIntervalSince1970: $0) } }
    var updateDate: Date { Date(timeIntervalSince1970: updatedAt) }

    var projectName: String {
        URL(fileURLWithPath: projectDir).lastPathComponent
    }

    var duration: TimeInterval {
        let end = endedAt ?? Date().timeIntervalSince1970
        return end - startedAt
    }

    var durationFormatted: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    var totalTokens: Int {
        (tokensInput ?? 0) + (tokensOutput ?? 0)
    }

    var tokensFormatted: String {
        let input = formatTokenCount(tokensInput ?? 0)
        let output = formatTokenCount(tokensOutput ?? 0)
        return "\(input) in · \(output) out"
    }

    var todoProgress: Double? {
        guard let total = todoTotal, total > 0, let completed = todoCompleted else { return nil }
        return Double(completed) / Double(total)
    }

    var isActive: Bool {
        status == .running || status == .thinking || status == .waitingForUser
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Factory

extension AgentSession {
    static func create(
        id: String,
        agentType: AgentType = .claudeCode,
        projectDir: String,
        model: String? = nil
    ) -> AgentSession {
        let now = Date().timeIntervalSince1970
        return AgentSession(
            id: id,
            agentType: agentType,
            status: .running,
            projectDir: projectDir,
            model: model,
            startedAt: now,
            updatedAt: now
        )
    }
}

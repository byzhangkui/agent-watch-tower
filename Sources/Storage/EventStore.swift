import Foundation
import GRDB

struct EventStore {
    let db: DatabaseQueue

    func insert(_ event: AgentEvent) throws {
        try db.write { db in
            try event.insert(db)
        }
    }

    func events(forSession sessionId: String, limit: Int = 100) throws -> [AgentEvent] {
        try db.read { db in
            try AgentEvent
                .filter(Column("session_id") == sessionId)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func recentEvents(forSession sessionId: String, limit: Int = 20) throws -> [AgentEvent] {
        try db.read { db in
            try AgentEvent
                .filter(Column("session_id") == sessionId)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Tool usage distribution for a session
    func toolUsageCounts(forSession sessionId: String) throws -> [(tool: String, count: Int)] {
        try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT tool_name, COUNT(*) as cnt
                FROM agent_event
                WHERE session_id = ? AND tool_name IS NOT NULL AND event_type = 'tool_call'
                GROUP BY tool_name
                ORDER BY cnt DESC
                """,
                arguments: [sessionId]
            )
            return rows.map { (tool: $0["tool_name"] as String, count: $0["cnt"] as Int) }
        }
    }

    /// Total token usage for a session
    func totalTokens(forSession sessionId: String) throws -> (input: Int, output: Int) {
        try db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(tokens_input), 0) as total_input,
                       COALESCE(SUM(tokens_output), 0) as total_output
                FROM agent_event
                WHERE session_id = ?
                """,
                arguments: [sessionId]
            )
            return (
                input: row?["total_input"] as? Int ?? 0,
                output: row?["total_output"] as? Int ?? 0
            )
        }
    }

    /// Event count for a session
    func eventCount(forSession sessionId: String) throws -> Int {
        try db.read { db in
            try AgentEvent
                .filter(Column("session_id") == sessionId)
                .fetchCount(db)
        }
    }
}

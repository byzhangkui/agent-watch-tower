import Foundation
import GRDB

struct AppDatabase {
    let dbQueue: DatabaseQueue

    init(path: String? = nil) throws {
        let dbPath = path ?? Constants.databasePath
        dbQueue = try DatabaseQueue(path: dbPath)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "agent_session") { t in
                t.primaryKey("id", .text)
                t.column("agent_type", .text).notNull().defaults(to: "claude-code")
                t.column("status", .text).notNull().defaults(to: "running")
                t.column("project_dir", .text).notNull()
                t.column("current_action", .text)
                t.column("todo_completed", .integer)
                t.column("todo_total", .integer)
                t.column("model", .text)
                t.column("started_at", .double).notNull()
                t.column("ended_at", .double)
                t.column("updated_at", .double).notNull()
                t.column("tokens_input", .integer)
                t.column("tokens_output", .integer)
            }

            try db.create(index: "idx_session_status", on: "agent_session", columns: ["status"])
            try db.create(index: "idx_session_started", on: "agent_session", columns: ["started_at"])

            try db.create(table: "agent_event") { t in
                t.primaryKey("id", .text)
                t.column("session_id", .text).notNull()
                    .references("agent_session", onDelete: .cascade)
                t.column("timestamp", .double).notNull()
                t.column("event_type", .text).notNull()
                t.column("tool_name", .text)
                t.column("input_summary", .text)
                t.column("output_summary", .text)
                t.column("tokens_input", .integer)
                t.column("tokens_output", .integer)
                t.column("duration_ms", .integer)
                t.column("raw_payload", .text)
            }

            try db.create(index: "idx_event_session", on: "agent_event", columns: ["session_id"])
            try db.create(index: "idx_event_time", on: "agent_event", columns: ["timestamp"])

            try db.create(table: "daily_usage") { t in
                t.primaryKey {
                    t.column("date", .text)
                    t.column("agent_type", .text)
                }
                t.column("total_sessions", .integer).defaults(to: 0)
                t.column("tokens_input", .integer).defaults(to: 0)
                t.column("tokens_output", .integer).defaults(to: 0)
                t.column("api_calls", .integer).defaults(to: 0)
                t.column("estimated_cost", .double).defaults(to: 0)
            }
        }

        return migrator
    }
}

// MARK: - Cleanup

extension AppDatabase {
    func cleanupOldEvents(olderThanDays days: Int = Constants.defaultRetentionDays) throws {
        let cutoff = Date().timeIntervalSince1970 - Double(days * 86400)
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM agent_event WHERE timestamp < ?",
                arguments: [cutoff]
            )
            // Clean up orphaned sessions with no events and ended
            try db.execute(
                sql: """
                    DELETE FROM agent_session
                    WHERE status IN ('completed', 'error')
                    AND ended_at IS NOT NULL
                    AND ended_at < ?
                    """,
                arguments: [cutoff]
            )
        }
    }
}

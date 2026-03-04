import Foundation
import GRDB

struct SessionStore {
    let db: DatabaseQueue

    func find(id: String) throws -> AgentSession? {
        try db.read { db in
            try AgentSession.fetchOne(db, key: id)
        }
    }

    func upsert(_ session: AgentSession) throws {
        try db.write { db in
            try session.save(db)
        }
    }

    func delete(_ session: AgentSession) throws {
        try db.write { db in
            _ = try session.delete(db)
        }
    }

    /// All sessions that are currently active (running, thinking, waiting)
    func activeSessions() throws -> [AgentSession] {
        try db.read { db in
            try AgentSession
                .filter(["running", "thinking", "waiting_for_user"].contains(Column("status")))
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    /// Active sessions plus today's completed sessions
    func todaySessions() throws -> [AgentSession] {
        let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return try db.read { db in
            try AgentSession
                .filter(
                    ["running", "thinking", "waiting_for_user"].contains(Column("status"))
                    || (Column("started_at") >= todayStart)
                )
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Recent sessions for history view
    func recentSessions(limit: Int = 50) throws -> [AgentSession] {
        try db.read { db in
            try AgentSession
                .order(Column("updated_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Count of currently active sessions
    func activeCount() throws -> Int {
        try db.read { db in
            try AgentSession
                .filter(["running", "thinking", "waiting_for_user"].contains(Column("status")))
                .fetchCount(db)
        }
    }

    /// Mark stale sessions (no update for 5+ minutes) as idle
    func markStaleSessions() throws {
        let staleThreshold = Date().timeIntervalSince1970 - 300 // 5 minutes
        try db.write { db in
            try db.execute(
                sql: """
                    UPDATE agent_session
                    SET status = 'idle', updated_at = ?
                    WHERE status IN ('running', 'thinking')
                    AND updated_at < ?
                    """,
                arguments: [Date().timeIntervalSince1970, staleThreshold]
            )
        }
    }
}

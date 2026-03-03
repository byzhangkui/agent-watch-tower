import Foundation
import GRDB

struct DailyUsageStore {
    let db: DatabaseQueue

    func usage(for date: String, agentType: String = "claude-code") throws -> DailyUsage? {
        try db.read { db in
            try DailyUsage.fetchOne(
                db,
                key: ["date": date, "agent_type": agentType]
            )
        }
    }

    func todayUsage(agentType: String = "claude-code") throws -> DailyUsage? {
        try usage(for: DailyUsage.todayString, agentType: agentType)
    }

    func todayTotalUsage() throws -> DailyUsage {
        try db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT
                    ? as date,
                    'all' as agent_type,
                    COALESCE(SUM(total_sessions), 0) as total_sessions,
                    COALESCE(SUM(tokens_input), 0) as tokens_input,
                    COALESCE(SUM(tokens_output), 0) as tokens_output,
                    COALESCE(SUM(api_calls), 0) as api_calls,
                    COALESCE(SUM(estimated_cost), 0) as estimated_cost
                FROM daily_usage
                WHERE date = ?
                """,
                arguments: [DailyUsage.todayString, DailyUsage.todayString]
            )

            guard let row else {
                return DailyUsage(
                    date: DailyUsage.todayString,
                    agentType: "all",
                    totalSessions: 0,
                    tokensInput: 0,
                    tokensOutput: 0,
                    apiCalls: 0,
                    estimatedCost: 0
                )
            }

            return DailyUsage(
                date: row["date"],
                agentType: row["agent_type"],
                totalSessions: row["total_sessions"],
                tokensInput: row["tokens_input"],
                tokensOutput: row["tokens_output"],
                apiCalls: row["api_calls"],
                estimatedCost: row["estimated_cost"]
            )
        }
    }

    func increment(
        date: String,
        agentType: String,
        tokensInput: Int = 0,
        tokensOutput: Int = 0,
        sessions: Int = 0,
        cost: Double = 0
    ) throws {
        try db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_usage (date, agent_type, total_sessions, tokens_input, tokens_output, api_calls, estimated_cost)
                    VALUES (?, ?, ?, ?, ?, 1, ?)
                    ON CONFLICT(date, agent_type) DO UPDATE SET
                        total_sessions = total_sessions + ?,
                        tokens_input = tokens_input + ?,
                        tokens_output = tokens_output + ?,
                        api_calls = api_calls + 1,
                        estimated_cost = estimated_cost + ?
                    """,
                arguments: [
                    date, agentType, sessions, tokensInput, tokensOutput, cost,
                    sessions, tokensInput, tokensOutput, cost
                ]
            )
        }
    }
}

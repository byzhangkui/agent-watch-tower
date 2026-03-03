import Foundation

/// Core event processing actor. Guarantees serial processing of hook events
/// and maintains state consistency across sessions.
actor EventProcessor {
    private let sessionStore: SessionStore
    private let eventStore: EventStore
    private let dailyUsageStore: DailyUsageStore
    private let adapters: [String: AgentAdapter]
    private let transcriptParser = TranscriptParser()
    private var pendingToolCalls: [String: Double] = [:] // toolUseId → startTimestamp

    init(
        sessionStore: SessionStore,
        eventStore: EventStore,
        dailyUsageStore: DailyUsageStore,
        adapters: [String: AgentAdapter]
    ) {
        self.sessionStore = sessionStore
        self.eventStore = eventStore
        self.dailyUsageStore = dailyUsageStore
        self.adapters = adapters
    }

    /// Process a hook event payload.
    func process(_ payload: HookPayload) {
        let adapter = adapters["claude-code"]!

        // 1. Update session
        let existing = try? sessionStore.find(id: payload.sessionId)
        var session = adapter.updateSession(from: payload, existing: existing)

        // 2. On Stop: parse transcript for supplementary data
        if payload.hookEventName == "Stop", let transcriptPath = payload.transcriptPath {
            if let result = transcriptParser.parse(transcriptPath) {
                // Precise completion status from stop_reason
                switch result.lastStopReason {
                case "end_turn":
                    session.status = .completed
                case "max_tokens":
                    session.status = .error
                default:
                    break // Keep adapter's status
                }

                // Token usage from transcript
                if result.totalInputTokens > 0 || result.totalOutputTokens > 0 {
                    session.tokensInput = result.totalInputTokens
                    session.tokensOutput = result.totalOutputTokens
                }

                // Update daily usage
                let cost = CostCalculator.estimate(
                    model: session.model ?? "claude-sonnet-4-6",
                    inputTokens: result.totalInputTokens,
                    outputTokens: result.totalOutputTokens
                )
                try? dailyUsageStore.increment(
                    date: DailyUsage.todayString,
                    agentType: session.agentType.rawValue,
                    tokensInput: result.totalInputTokens,
                    tokensOutput: result.totalOutputTokens,
                    sessions: 1,
                    cost: cost
                )
            }
        }

        // 3. On SessionStart: increment daily session count
        if payload.hookEventName == "SessionStart" {
            try? dailyUsageStore.increment(
                date: DailyUsage.todayString,
                agentType: "claude-code",
                sessions: 1
            )
        }

        try? sessionStore.upsert(session)

        // 4. Create event record
        if var event = adapter.parseEvent(from: payload) {
            // Calculate tool call duration from Pre→Post time difference
            if payload.hookEventName == "PreToolUse", let toolId = payload.toolUseId {
                pendingToolCalls[toolId] = Date().timeIntervalSince1970
            }
            if payload.hookEventName == "PostToolUse", let toolId = payload.toolUseId {
                if let startTime = pendingToolCalls.removeValue(forKey: toolId) {
                    event.durationMs = Int((Date().timeIntervalSince1970 - startTime) * 1000)
                }
            }

            try? eventStore.insert(event)
        }

        // 5. Notify UI (post to main thread)
        let sessionId = payload.sessionId
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .sessionDidUpdate,
                object: nil,
                userInfo: ["sessionId": sessionId]
            )
        }
    }
}

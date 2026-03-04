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
        // Determine agent type. 
        // Gemini uses 'SessionEnd', 'BeforeTool', 'AfterTool' and provides a 'timestamp'.
        let isGemini = payload.timestamp != nil || 
                       ["SessionEnd", "BeforeTool", "AfterTool", "BeforeAgent", "AfterAgent"].contains(payload.hookEventName)
        let adapterKey = isGemini ? "gemini" : "claude-code"
        
        guard let adapter = adapters[adapterKey] else {
            print("EventProcessor: No adapter found for \(adapterKey)")
            return
        }

        // 1. Update session
        let existing = try? sessionStore.find(id: payload.sessionId)
        var session = adapter.updateSession(from: payload, existing: existing)

        // 2. On Stop/SessionEnd: parse transcript for supplementary data if available
        if (payload.hookEventName == "Stop" || payload.hookEventName == "SessionEnd"), let transcriptPath = payload.transcriptPath {
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
                let defaultModel = isGemini ? "gemini-2.5-pro" : "claude-sonnet-4-6"
                let cost = CostCalculator.estimate(
                    model: session.model ?? defaultModel,
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
                agentType: adapterKey,
                sessions: 1
            )
        }

        try? sessionStore.upsert(session)

        // 4. Create event record
        if var event = adapter.parseEvent(from: payload) {
            // Calculate tool call duration from Pre→Post time difference
            let isPreTool = payload.hookEventName == "PreToolUse" || payload.hookEventName == "BeforeTool"
            let isPostTool = payload.hookEventName == "PostToolUse" || payload.hookEventName == "AfterTool"
            let toolId = payload.toolUseId ?? payload.id
            
            if isPreTool, let toolId = toolId {
                pendingToolCalls[toolId] = payload.timestampDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            }
            if isPostTool, let toolId = toolId {
                if let startTime = pendingToolCalls.removeValue(forKey: toolId) {
                    let endTime = payload.timestampDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                    event.durationMs = Int((endTime - startTime) * 1000)
                }
            }

            do {
                try eventStore.insert(event)
            } catch {
                print("EventProcessor: failed to insert event \(event.id): \(error)")
            }
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

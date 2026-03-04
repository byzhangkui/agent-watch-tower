#if canImport(AppKit)
import Foundation
import Observation

@Observable
@MainActor
final class SessionDetailViewModel {
    var session: AgentSession
    var events: [AgentEvent] = []
    var toolUsage: [(tool: String, count: Int)] = []
    var totalTokensInput: Int = 0
    var totalTokensOutput: Int = 0
    var estimatedCost: Double = 0

    private let sessionStore: SessionStore
    private let eventStore: EventStore
    @ObservationIgnored nonisolated(unsafe) private var observer: Any?

    init(session: AgentSession, sessionStore: SessionStore, eventStore: EventStore) {
        self.session = session
        self.sessionStore = sessionStore
        self.eventStore = eventStore

        observer = NotificationCenter.default.addObserver(
            forName: .sessionDidUpdate, object: nil, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self else { return }
                let updatedId = notification.userInfo?["sessionId"] as? String
                guard updatedId == self.session.id else { return }
                self.reload()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() {
        // Refresh session
        if let updated = try? sessionStore.find(id: session.id) {
            session = updated
        }

        // Refresh events
        events = (try? eventStore.events(forSession: session.id)) ?? []

        // Refresh tool usage
        toolUsage = (try? eventStore.toolUsageCounts(forSession: session.id)) ?? []

        // Refresh token totals
        if let sessionTokensIn = session.tokensInput, let sessionTokensOut = session.tokensOutput {
            totalTokensInput = sessionTokensIn
            totalTokensOutput = sessionTokensOut
        } else if let tokens = try? eventStore.totalTokens(forSession: session.id) {
            totalTokensInput = tokens.input
            totalTokensOutput = tokens.output
        }

        // Calculate cost
        estimatedCost = CostCalculator.estimate(
            model: session.model ?? "claude-sonnet-4-6",
            inputTokens: totalTokensInput,
            outputTokens: totalTokensOutput
        )
    }

    var totalTokens: Int {
        totalTokensInput + totalTokensOutput
    }

    var maxToolCount: Int {
        toolUsage.first?.count ?? 1
    }
}
#endif

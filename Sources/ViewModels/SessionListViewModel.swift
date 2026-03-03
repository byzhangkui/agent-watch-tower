#if canImport(AppKit)
import Foundation
import Observation

@Observable
@MainActor
final class SessionListViewModel {
    var sessions: [AgentSession] = []
    var dailyTokens: Int = 0
    var dailyCost: Double = 0.0
    var dailySessions: Int = 0

    private let sessionStore: SessionStore
    private let dailyUsageStore: DailyUsageStore
    @ObservationIgnored nonisolated(unsafe) private var observer: Any?

    init(sessionStore: SessionStore, dailyUsageStore: DailyUsageStore) {
        self.sessionStore = sessionStore
        self.dailyUsageStore = dailyUsageStore

        observer = NotificationCenter.default.addObserver(
            forName: .sessionDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() {
        sessions = (try? sessionStore.todaySessions()) ?? []

        if let usage = try? dailyUsageStore.todayTotalUsage() {
            dailyTokens = usage.totalTokens
            dailyCost = usage.estimatedCost
            dailySessions = usage.totalSessions
        }
    }

    var activeSessions: [AgentSession] {
        sessions.filter { $0.isActive }
    }

    var completedSessions: [AgentSession] {
        sessions.filter { !$0.isActive }
    }

    var activeCount: Int {
        activeSessions.count
    }

    var hasError: Bool {
        sessions.contains { $0.status == .error }
    }
}
#endif

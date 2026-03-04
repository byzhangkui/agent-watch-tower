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
    @ObservationIgnored nonisolated(unsafe) private var refreshTimer: Timer?

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

        // Fallback: reload every 2 seconds so UI stays in sync even if a hook notification is missed
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        refreshTimer?.invalidate()
    }

    func reload() {
        // Keep existing sessions on DB error to avoid flickering / disappearing
        do {
            let fetched = try sessionStore.todaySessions()
            print("SessionListViewModel: Fetched \(fetched.count) sessions from DB. Active: \(fetched.filter { $0.isActive }.count), Completed: \(fetched.filter { !$0.isActive }.count)")
            self.sessions = fetched
        } catch {
            print("SessionListViewModel Error fetching sessions: \(error)")
        }

        do {
            let usage = try dailyUsageStore.todayTotalUsage()
            self.dailyTokens = usage.totalTokens
            self.dailyCost = usage.estimatedCost
            self.dailySessions = usage.totalSessions
        } catch {
            print("SessionListViewModel Error fetching daily usage: \(error)")
        }
    }

    func delete(session: AgentSession) {
        do {
            try sessionStore.delete(session)
            reload()
        } catch {
            print("Failed to delete session: \(error)")
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

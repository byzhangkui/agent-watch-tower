#if canImport(AppKit)
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Infrastructure
    private var database: AppDatabase!
    private var sessionStore: SessionStore!
    private var eventStore: EventStore!
    private var dailyUsageStore: DailyUsageStore!
    private var eventProcessor: EventProcessor!
    private var eventServer: EventServer!

    // Window management
    private var statusBarController: StatusBarController!
    private var popoverManager: PopoverManager!
    private var floatingPanelController: FloatingPanelController!

    // View models
    private var sessionListVM: SessionListViewModel!

    // Timers
    private var statusUpdateTimer: Timer?
    private var cleanupTimer: Timer?

    // Settings Window
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // 1. Initialize storage
        do {
            database = try AppDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
        sessionStore = SessionStore(db: database.dbQueue)
        eventStore = EventStore(db: database.dbQueue)
        dailyUsageStore = DailyUsageStore(db: database.dbQueue)

        // 2. Initialize adapters & processor
        let claudeAdapter = ClaudeCodeAdapter()
        let geminiAdapter = GeminiAdapter()
        eventProcessor = EventProcessor(
            sessionStore: sessionStore,
            eventStore: eventStore,
            dailyUsageStore: dailyUsageStore,
            adapters: [
                "claude-code": claudeAdapter,
                "gemini": geminiAdapter
            ]
        )

        // 3. Initialize HTTP server
        let router = EventRouter(processor: eventProcessor)
        eventServer = EventServer(eventRouter: router)
        do {
            try eventServer.start()
        } catch {
            print("Warning: Failed to start HTTP server: \(error)")
        }

        // 4. Initialize view models
        sessionListVM = SessionListViewModel(
            sessionStore: sessionStore,
            dailyUsageStore: dailyUsageStore
        )

        // 5. Initialize floating panel with CompactSessionListView
        floatingPanelController = FloatingPanelController { [weak self] in
            guard let self else { return NSView() }
            let compactView = CompactSessionListView(viewModel: self.sessionListVM)
            return NSHostingView(rootView: compactView)
        }

        // 6. Initialize popover with PanelRootView
        let rootView = PanelRootView(
            viewModel: sessionListVM,
            sessionStore: sessionStore,
            eventStore: eventStore,
            onOpenWindow: { [weak self] in
                self?.openFloatingWindow()
            },
            onShowSettings: { [weak self] in self?.showSettings() }
        )
        popoverManager = PopoverManager(contentView: rootView)

        // 7. Initialize status bar
        statusBarController = StatusBarController { [weak self] in
            guard let self, let button = self.statusBarController.button else { return }
            self.popoverManager.toggle(relativeTo: button)
        }

        // 8. Start periodic tasks
        startPeriodicTasks()

        // 9. Load initial data
        sessionListVM.reload()
        updateStatusBarIcon()
        
        // 10. Restore floating panel state
        floatingPanelController.restoreState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusUpdateTimer?.invalidate()
        cleanupTimer?.invalidate()
        floatingPanelController?.close()
        eventServer?.stop()
    }

    // MARK: - Window Management

    private func openFloatingWindow() {
        popoverManager.close()
        floatingPanelController.show()
    }

    @MainActor
    @objc func showSettings() {
        // Close popover first to avoid transient-behavior conflicts
        if popoverManager.isShown {
            popoverManager.close()
        }

        if let window = settingsWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()

        let hostingView = NSHostingView(rootView: SettingsView())
        window.contentView = hostingView

        self.settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Periodic Tasks

    private func startPeriodicTasks() {
        // Update status bar icon every 2 seconds
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusBarIcon()
            }
        }

        // Cleanup old data daily (check every hour)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            try? self?.database.cleanupOldEvents()
            try? self?.sessionStore.markStaleSessions()
        }
    }

    @MainActor
    private func updateStatusBarIcon() {
        let activeCount = sessionListVM.activeCount
        let hasError = sessionListVM.hasError

        if hasError {
            statusBarController.updateIcon(.error)
        } else if activeCount > 0 {
            statusBarController.updateIcon(.running(activeCount))
        } else {
            statusBarController.updateIcon(.idle)
        }
    }
}
#endif

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
    private var pinStateManager: PinStateManager!

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
        let adapter = ClaudeCodeAdapter()
        eventProcessor = EventProcessor(
            sessionStore: sessionStore,
            eventStore: eventStore,
            dailyUsageStore: dailyUsageStore,
            adapters: ["claude-code": adapter]
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

        // 5. Initialize window management
        let contentViewProvider: () -> NSView = { [weak self] in
            guard let self else { return NSView() }
            let rootView = PanelRootView(
                viewModel: self.sessionListVM,
                pinStateManager: self.pinStateManager,
                sessionStore: self.sessionStore,
                eventStore: self.eventStore
            )
            return NSHostingView(rootView: rootView)
        }

        // Create managers - need to be created in the right order
        floatingPanelController = FloatingPanelController(contentViewProvider: contentViewProvider)

        // Create a temporary popover manager to break the circular dependency
        popoverManager = PopoverManager(contentView: EmptyView())
        pinStateManager = PinStateManager(
            popoverManager: popoverManager,
            floatingPanel: floatingPanelController
        )

        // Now recreate the popover with the real content
        let realRootView = PanelRootView(
            viewModel: sessionListVM,
            pinStateManager: pinStateManager,
            sessionStore: sessionStore,
            eventStore: eventStore
        )
        popoverManager = PopoverManager(contentView: realRootView)

        // Update pin state manager with real popover
        pinStateManager = PinStateManager(
            popoverManager: popoverManager,
            floatingPanel: floatingPanelController
        )

        // 6. Initialize status bar
        statusBarController = StatusBarController { [weak self] in
            guard let self, let button = self.statusBarController.button else { return }
            self.pinStateManager.handleStatusBarClick(button: button)
        }

        // 7. Start periodic tasks
        startPeriodicTasks()

        // 8. Load initial data
        sessionListVM.reload()
        updateStatusBarIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusUpdateTimer?.invalidate()
        cleanupTimer?.invalidate()
        eventServer?.stop()
    }

    // MARK: - Window Management

    @MainActor
    @objc func showSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

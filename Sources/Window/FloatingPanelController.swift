#if canImport(AppKit)
import AppKit
import SwiftUI

/// Manages the always-on-top floating panel (NSPanel) as an independent window.
/// Uses a transparent titlebar with standard close button for a minimal appearance.
final class FloatingPanelController {
    private var panel: NSPanel?
    private let contentViewProvider: () -> NSView

    // UserDefaults keys for saving/restoring window position
    private static let positionXKey = "FloatingPanel.positionX"
    private static let positionYKey = "FloatingPanel.positionY"
    private static let hasSavedPositionKey = "FloatingPanel.hasSavedPosition"
    private static let isVisibleKey = "FloatingPanel.isVisible"

    init(contentViewProvider: @escaping () -> NSView) {
        self.contentViewProvider = contentViewProvider
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Toggle panel visibility — show if hidden, hide if visible.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Restore panel state from previous launch. Call this after initialization.
    func restoreState() {
        if UserDefaults.standard.bool(forKey: Self.isVisibleKey) {
            show()
        }
    }

    /// Show the floating panel, creating it if needed.
    func show() {
        if let panel = panel {
            panel.orderFrontRegardless()
            UserDefaults.standard.set(true, forKey: Self.isVisibleKey)
            return
        }

        let contentView = contentViewProvider()

        let fittingSize = contentView.fittingSize
        let width = max(fittingSize.width, Constants.panelDefaultWidth)
        let height = max(fittingSize.height, Constants.panelMinHeight)

        let origin = savedPosition() ?? defaultOrigin(for: NSSize(width: width, height: height))
        let frame = NSRect(origin: origin, size: NSSize(width: width, height: height))

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Transparent titlebar — only the close button remains visible
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.title = Constants.appName

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        
        let containerView = NSView()
        visualEffect.frame = containerView.bounds
        visualEffect.autoresizingMask = [.width, .height]
        containerView.addSubview(visualEffect)
        
        contentView.frame = containerView.bounds
        contentView.autoresizingMask = [.width, .height]
        containerView.addSubview(contentView)

        panel.minSize = NSSize(width: Constants.panelMinWidth, height: Constants.panelMinHeight)
        panel.maxSize = NSSize(width: Constants.panelMaxWidth, height: Constants.panelMaxHeight)

        panel.contentView = containerView
        panel.orderFrontRegardless()
        self.panel = panel
        
        // Ensure the restored position is visible on the current screens, otherwise reset
        if !isFrameVisibleOnAnyScreen(panel.frame) {
            panel.setFrameOrigin(defaultOrigin(for: panel.frame.size))
        }

        UserDefaults.standard.set(true, forKey: Self.isVisibleKey)

        // Save position when the window moves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        
        // Listen for close to update visibility state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }

    /// Hide the panel without destroying it (preserves state for quick reshow).
    func hide() {
        savePosition()
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.isVisibleKey)
    }

    /// Destroy the panel (call on app termination or full teardown).
    func close() {
        savePosition()
        if let panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: panel)
            panel.close()
        }
        panel = nil
    }

    // MARK: - Private

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: Self.isVisibleKey)
    }

    private func savePosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(Double(frame.origin.x), forKey: Self.positionXKey)
        UserDefaults.standard.set(Double(frame.origin.y), forKey: Self.positionYKey)
        UserDefaults.standard.set(true, forKey: Self.hasSavedPositionKey)
    }

    private func savedPosition() -> NSPoint? {
        guard UserDefaults.standard.bool(forKey: Self.hasSavedPositionKey) else { return nil }
        let x = UserDefaults.standard.double(forKey: Self.positionXKey)
        let y = UserDefaults.standard.double(forKey: Self.positionYKey)
        return NSPoint(x: x, y: y)
    }

    /// Default position: top-right corner of the primary screen.
    private func defaultOrigin(for size: NSSize) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(
            x: screenFrame.maxX - size.width - 20,
            y: screenFrame.maxY - size.height - 20
        )
    }
    
    /// Checks if the given frame intersects with any of the currently available screens.
    private func isFrameVisibleOnAnyScreen(_ frame: NSRect) -> Bool {
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }
}
#endif

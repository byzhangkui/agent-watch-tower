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

    /// Show the floating panel, creating it if needed.
    func show() {
        if let panel = panel {
            panel.orderFrontRegardless()
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
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor(red: 30/255.0, green: 30/255.0, blue: 32/255.0, alpha: 0.98)

        panel.minSize = NSSize(width: Constants.panelMinWidth, height: Constants.panelMinHeight)
        panel.maxSize = NSSize(width: Constants.panelMaxWidth, height: Constants.panelMaxHeight)

        panel.contentView = contentView
        panel.orderFrontRegardless()
        self.panel = panel

        // Save position when the window moves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    /// Hide the panel without destroying it (preserves state for quick reshow).
    func hide() {
        savePosition()
        panel?.orderOut(nil)
    }

    /// Destroy the panel (call on app termination or full teardown).
    func close() {
        savePosition()
        if let panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            panel.close()
        }
        panel = nil
    }

    // MARK: - Private

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
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

    /// Default position: top-right corner of the screen.
    private func defaultOrigin(for size: NSSize) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(
            x: screenFrame.maxX - size.width - 20,
            y: screenFrame.maxY - size.height - 20
        )
    }
}
#endif

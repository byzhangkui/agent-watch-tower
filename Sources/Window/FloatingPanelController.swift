#if canImport(AppKit)
import AppKit
import SwiftUI

/// Manages the always-on-top floating panel (NSPanel) as an independent window.
/// Uses a transparent titlebar with standard close button for a minimal appearance.
final class FloatingPanelController {
    private var panel: NSPanel?
    private let contentViewProvider: () -> NSView

    // UserDefaults keys for saving/restoring window position and size
    private static let positionXKey = "FloatingPanel.positionX"
    private static let positionYKey = "FloatingPanel.positionY"
    private static let sizeWidthKey = "FloatingPanel.sizeWidth"
    private static let sizeHeightKey = "FloatingPanel.sizeHeight"
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
        let defaultWidth = max(fittingSize.width, Constants.panelDefaultWidth)
        let defaultHeight = max(fittingSize.height, Constants.panelMinHeight)

        let savedFrame = savedFrame()
        let size = savedFrame?.size ?? NSSize(width: defaultWidth, height: defaultHeight)
        let origin = savedFrame?.origin ?? defaultOrigin(for: size)
        let frame = NSRect(origin: origin, size: size)

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
        panel.backgroundColor = NSColor(red: 40/255.0, green: 40/255.0, blue: 40/255.0, alpha: 1.0)
        panel.isOpaque = true

        panel.minSize = NSSize(width: Constants.panelMinWidth, height: Constants.panelMinHeight)
        panel.maxSize = NSSize(width: Constants.panelMaxWidth, height: Constants.panelMaxHeight)

        panel.contentView = contentView
        panel.orderFrontRegardless()
        self.panel = panel
        
        // Ensure the restored position is visible on the current screens, otherwise reset
        if !isFrameVisibleOnAnyScreen(panel.frame) {
            let defaultSize = NSSize(width: defaultWidth, height: defaultHeight)
            panel.setFrameOrigin(defaultOrigin(for: defaultSize))
        }

        UserDefaults.standard.set(true, forKey: Self.isVisibleKey)

        // Save position and size when the window moves or resizes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didResizeNotification,
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
        saveState()
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.isVisibleKey)
    }

    /// Destroy the panel (call on app termination or full teardown).
    func close() {
        saveState()
        if let panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: panel)
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: panel)
            panel.close()
        }
        panel = nil
    }

    // MARK: - Private

    @objc private func windowDidMoveOrResize(_ notification: Notification) {
        saveState()
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: Self.isVisibleKey)
    }

    private func saveState() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(Double(frame.origin.x), forKey: Self.positionXKey)
        UserDefaults.standard.set(Double(frame.origin.y), forKey: Self.positionYKey)
        UserDefaults.standard.set(Double(frame.size.width), forKey: Self.sizeWidthKey)
        UserDefaults.standard.set(Double(frame.size.height), forKey: Self.sizeHeightKey)
        UserDefaults.standard.set(true, forKey: Self.hasSavedPositionKey)
    }

    private func savedFrame() -> NSRect? {
        guard UserDefaults.standard.bool(forKey: Self.hasSavedPositionKey) else { return nil }
        let x = UserDefaults.standard.double(forKey: Self.positionXKey)
        let y = UserDefaults.standard.double(forKey: Self.positionYKey)
        let width = UserDefaults.standard.double(forKey: Self.sizeWidthKey)
        let height = UserDefaults.standard.double(forKey: Self.sizeHeightKey)
        
        if width > 0 && height > 0 {
            return NSRect(x: x, y: y, width: width, height: height)
        }
        return NSRect(x: x, y: y, width: Double(Constants.panelDefaultWidth), height: Double(Constants.panelMinHeight))
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

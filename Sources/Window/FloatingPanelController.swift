#if canImport(AppKit)
import AppKit
import SwiftUI

/// Manages the always-on-top floating panel (NSPanel).
final class FloatingPanelController {
    private var panel: NSPanel?
    private let contentViewProvider: () -> NSView

    init(contentViewProvider: @escaping () -> NSView) {
        self.contentViewProvider = contentViewProvider
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(at frame: NSRect? = nil) {
        if let panel = panel {
            // Reuse existing panel — just reposition and bring to front
            let targetFrame = frame ?? panel.frame
            panel.setFrame(targetFrame, display: false, animate: false)
            panel.orderFrontRegardless()
            return
        }

        // First time: create the panel
        let targetFrame = frame ?? defaultFrame()
        let panel = NSPanel(
            contentRect: targetFrame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = Constants.appName
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.minSize = NSSize(width: Constants.panelMinWidth, height: Constants.panelMinHeight)
        panel.maxSize = NSSize(width: Constants.panelMaxWidth, height: Constants.panelMaxHeight)

        panel.contentView = contentViewProvider()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Hide the panel without destroying it (preserves state for quick reshow).
    func hide() {
        panel?.orderOut(nil)
    }

    /// Destroy the panel (call on app termination or full teardown).
    func close() {
        panel?.close()
        panel = nil
    }

    var currentFrame: NSRect? {
        panel?.frame
    }

    // MARK: - Private

    private func defaultFrame() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return NSRect(
            x: screenFrame.maxX - Constants.panelDefaultWidth - 20,
            y: screenFrame.maxY - Constants.panelDefaultHeight - 20,
            width: Constants.panelDefaultWidth,
            height: Constants.panelDefaultHeight
        )
    }
}
#endif

#if canImport(AppKit)
import AppKit
import Observation

/// Coordinates the transition between Popover mode and Floating Panel mode.
@Observable
final class PinStateManager {
    var isPinned: Bool = false
    private(set) var lastPinnedFrame: NSRect?

    private let popoverManager: PopoverManager
    private let floatingPanel: FloatingPanelController

    init(popoverManager: PopoverManager, floatingPanel: FloatingPanelController) {
        self.popoverManager = popoverManager
        self.floatingPanel = floatingPanel
    }

    func togglePin() {
        isPinned.toggle()

        if isPinned {
            // Popover → Floating Panel
            let frame = popoverManager.currentFrame ?? lastPinnedFrame
            popoverManager.close()
            floatingPanel.show(at: frame)
        } else {
            // Floating Panel → Popover
            lastPinnedFrame = floatingPanel.currentFrame
            floatingPanel.close()
            // Popover will be shown on next status bar click
        }
    }

    func handleStatusBarClick(button: NSStatusBarButton) {
        if isPinned {
            // In Pin mode, clicking menu bar toggles the floating panel
            if floatingPanel.isVisible {
                floatingPanel.close()
            } else {
                floatingPanel.show(at: lastPinnedFrame)
            }
        } else {
            popoverManager.toggle(relativeTo: button)
        }
    }
}
#endif

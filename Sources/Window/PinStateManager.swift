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
            // Popover → Floating Panel: capture popover position, close it, show panel there
            let frame = popoverManager.currentFrame ?? lastPinnedFrame
            popoverManager.close()
            floatingPanel.show(at: frame)
        } else {
            // Floating Panel → Popover: hide (don't destroy) so panel can be reused
            lastPinnedFrame = floatingPanel.currentFrame
            floatingPanel.hide()
            // Popover will be shown on next status bar click
        }
    }

    func handleStatusBarClick(button: NSStatusBarButton) {
        if isPinned {
            // In Pin mode, clicking menu bar toggles the floating panel
            if floatingPanel.isVisible {
                floatingPanel.hide()
            } else {
                floatingPanel.show(at: lastPinnedFrame)
            }
        } else {
            popoverManager.toggle(relativeTo: button)
        }
    }
}
#endif

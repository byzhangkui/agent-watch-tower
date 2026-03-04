#if canImport(AppKit)
import AppKit
import SwiftUI

/// Manages the NSPopover that appears when clicking the menu bar icon.
final class PopoverManager {
    private let popover: NSPopover

    init<Content: View>(contentView: Content) {
        popover = NSPopover()
        popover.contentSize = NSSize(
            width: Constants.popoverWidth,
            height: Constants.popoverMaxHeight
        )
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    var isShown: Bool { popover.isShown }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )

        // Ensure popover window doesn't activate the app
        if let window = popover.contentViewController?.view.window {
            window.level = .floating
        }
    }

    func close() {
        popover.performClose(nil)
    }

    /// Get the current popover frame for Pin transition
    var currentFrame: NSRect? {
        popover.contentViewController?.view.window?.frame
    }
}
#endif

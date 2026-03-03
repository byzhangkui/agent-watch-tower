#if canImport(AppKit)
import SwiftUI

/// Root view for the panel, containing toolbar, daily summary, and session list.
struct PanelRootView: View {
    let viewModel: SessionListViewModel
    let pinStateManager: PinStateManager
    let sessionStore: SessionStore
    let eventStore: EventStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                PanelToolbarView(
                    isPinned: pinStateManager.isPinned,
                    onPin: { pinStateManager.togglePin() },
                    onSettings: { openSettings() }
                )

                Divider()

                // Daily summary
                DailySummaryView(
                    totalTokens: viewModel.dailyTokens,
                    estimatedCost: viewModel.dailyCost
                )

                Divider()

                // Session list
                SessionListView(
                    viewModel: viewModel,
                    sessionStore: sessionStore,
                    eventStore: eventStore
                )
            }
            .frame(
                minWidth: Constants.panelMinWidth,
                maxWidth: Constants.panelMaxWidth,
                minHeight: Constants.panelMinHeight,
                maxHeight: Constants.panelMaxHeight
            )
        }
    }

    @Environment(\.openWindow) private var openWindow

    private func openSettings() {
        #if canImport(AppKit)
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSettings()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        #endif
    }
}
#endif

#if canImport(AppKit)
import SwiftUI

/// Root view for the panel, containing toolbar, daily summary, and session list.
struct PanelRootView: View {
    let viewModel: SessionListViewModel
    let pinStateManager: PinStateManager
    let sessionStore: SessionStore
    let eventStore: EventStore
    let onShowSettings: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                PanelToolbarView(
                    isPinned: pinStateManager.isPinned,
                    onPin: { pinStateManager.togglePin() },
                    onSettings: onShowSettings
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
}
#endif

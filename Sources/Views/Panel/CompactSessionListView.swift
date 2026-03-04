#if canImport(AppKit)
import SwiftUI

/// Compact view for the independent always-on-top window.
/// Shows daily summary + session cards without navigation.
struct CompactSessionListView: View {
    let viewModel: SessionListViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Daily summary
            DailySummaryView(
                totalTokens: viewModel.dailyTokens,
                estimatedCost: viewModel.dailyCost
            )

            Divider()

            // Session cards
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Constants.cardSpacing) {
                        // Active sessions
                        ForEach(viewModel.activeSessions) { session in
                            SessionCardView(session: session)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                        }

                        // Completed sessions
                        if !viewModel.completedSessions.isEmpty {
                            Divider()
                                .padding(.horizontal, Constants.contentPadding)

                            ForEach(viewModel.completedSessions) { session in
                                SessionCardView(session: session)
                                    .opacity(0.7)
                            }
                        }
                    }
                    .padding(.horizontal, Constants.contentPadding)
                    .padding(.vertical, Constants.cardSpacing)
                    .animation(.spring(duration: 0.3), value: viewModel.sessions)
                }
            }
        }
        .frame(width: Constants.panelDefaultWidth)
        .onAppear {
            viewModel.reload()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text("No active sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
#endif

#if canImport(AppKit)
import SwiftUI

/// Compact view for the independent always-on-top window.
/// Dark themed, minimal, shows session cards only.
struct CompactSessionListView: View {
    let viewModel: SessionListViewModel

    var body: some View {
        if viewModel.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.activeSessions) { session in
                        SessionCardView(session: session, showTokenUsage: false) {
                            viewModel.delete(session: session)
                        }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                        if session.id != viewModel.activeSessions.last?.id || !viewModel.completedSessions.isEmpty {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }

                    ForEach(viewModel.completedSessions) { session in
                        SessionCardView(session: session, showTokenUsage: false) {
                            viewModel.delete(session: session)
                        }
                            .opacity(0.6)
                        if session.id != viewModel.completedSessions.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .animation(.spring(duration: 0.3), value: viewModel.sessions)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)

            Text("No active sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: Constants.panelMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
        .padding(.bottom, 30)
    }
}
#endif

#if canImport(AppKit)
import SwiftUI

/// Main session list view showing active and recent sessions.
struct SessionListView: View {
    let viewModel: SessionListViewModel
    let sessionStore: SessionStore
    let eventStore: EventStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Active sessions
                if !viewModel.activeSessions.isEmpty {
                    ForEach(viewModel.activeSessions) { session in
                        NavigationLink(value: session) {
                            SessionCardView(session: session) {
                                viewModel.delete(session: session)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                        
                        if session.id != viewModel.activeSessions.last?.id || !viewModel.completedSessions.isEmpty {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }

                // Completed sessions (today)
                if !viewModel.completedSessions.isEmpty {
                    ForEach(viewModel.completedSessions) { session in
                        NavigationLink(value: session) {
                            SessionCardView(session: session) {
                                viewModel.delete(session: session)
                            }
                                .opacity(0.7)
                        }
                        .buttonStyle(.plain)
                        
                        if session.id != viewModel.completedSessions.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }

                // Empty state
                if viewModel.sessions.isEmpty {
                    emptyState
                }
            }
            .padding(.vertical, Constants.cardSpacing)
            .animation(.spring(duration: 0.3), value: viewModel.sessions)
        }
        .navigationDestination(for: AgentSession.self) { session in
            SessionDetailView(
                viewModel: SessionDetailViewModel(
                    session: session,
                    sessionStore: sessionStore,
                    eventStore: eventStore
                )
            )
        }
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

            Text("Start a Claude Code session\nto see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
#endif

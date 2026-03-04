#if canImport(AppKit)
import SwiftUI

/// A compact card displaying a single agent session's status.
struct SessionCardView: View {
    let session: AgentSession
    var showTokenUsage: Bool = true

    @State private var alertPulse = false

    private var isWaiting: Bool { session.status == .waitingForUser }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Status indicator + agent type + duration
            HStack {
                StatusIndicator(status: session.status)

                Text(session.agentType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(agentColor)

                Spacer()

                // Waiting-for-user badge
                if isWaiting {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("Needs Input")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.orange)
                    .opacity(alertPulse ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: alertPulse
                    )
                    .onAppear { alertPulse = true }
                }

                // Live duration for active sessions, static for completed
                if session.isActive {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        durationLabel(now: context.date)
                    }
                } else {
                    durationLabel(now: Date())
                }
            }

            // Row 2: Project directory
            Text(session.projectName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Row 3: Current action
            if let action = session.currentAction {
                HStack(spacing: 4) {
                    actionIcon
                    Text(action)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
            } else if session.status == .completed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                    Text("Completed")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Row 4: Progress bar (if available)
            if let completed = session.todoCompleted, let total = session.todoTotal, total > 0 {
                ProgressBarView(completed: completed, total: total)
            }

            // Row 5: Token usage
            if showTokenUsage, session.totalTokens > 0 {
                TokenBadgeView(
                    inputTokens: session.tokensInput ?? 0,
                    outputTokens: session.tokensOutput ?? 0
                )
            }
        }
        .padding(Constants.contentPadding)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                .stroke(Color.orange, lineWidth: isWaiting ? 1.5 : 0)
                .opacity(isWaiting ? (alertPulse ? 0.8 : 0.3) : 0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: alertPulse
                )
        )
    }

    // MARK: - Private

    private func durationLabel(now: Date) -> some View {
        let end = session.endDate ?? now
        let seconds = end.timeIntervalSince(session.startDate)
        let minutes = Int(seconds / 60)
        let text = minutes < 60
            ? "\(minutes)m"
            : "\(minutes / 60)h \(minutes % 60)m"
        return HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var agentColor: Color {
        Color(hex: session.agentType.brandColor)
    }

    @ViewBuilder
    private var actionIcon: some View {
        switch session.status {
        case .thinking:
            Image(systemName: "brain")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .running:
            Image(systemName: "play.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .waitingForUser:
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
        default:
            EmptyView()
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
#endif

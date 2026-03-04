#if canImport(AppKit)
import SwiftUI

/// A compact card displaying a single agent session's status.
struct SessionCardView: View {
    let session: AgentSession
    var showTokenUsage: Bool = true
    var onRemove: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @State private var alertPulse = false
    @State private var isHovered = false

    private var isWaiting: Bool { session.status == .waitingForUser }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator dot
            StatusIndicator(status: session.status)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Agent type + duration
                HStack(alignment: .top) {
                    Text(session.agentType.displayName)
                        .font(.system(size: 14, weight: .semibold))
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
                    
                    if let onRemove {
                        Button(action: onRemove) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .help("Remove Session")
                    }
                }

                // Row 2: Project directory
                Text(session.projectName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Row 3: Current action
                if session.status == .completed {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Completed")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                } else if let action = session.currentAction {
                    HStack(spacing: 6) {
                        if session.status == .running {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                            Text(action)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } else {
                            Text(action)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Row 4: Progress bar (if available)
                if let completed = session.todoCompleted, let total = session.todoTotal, total > 0 {
                    ProgressBarView(completed: completed, total: total)
                        .padding(.top, 4)
                }

                // Row 5: Token usage
                if showTokenUsage, session.totalTokens > 0 {
                    TokenBadgeView(
                        inputTokens: session.tokensInput ?? 0,
                        outputTokens: session.tokensOutput ?? 0
                    )
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove Session", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Private

    private func durationLabel(now: Date) -> some View {
        let end = session.endDate ?? now
        let seconds = end.timeIntervalSince(session.startDate)
        let minutes = Int(seconds / 60)
        let text = minutes < 60
            ? "\(minutes)m"
            : "\(minutes / 60)h \(minutes % 60)m"
        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13))
        }
        .foregroundStyle(.secondary)
    }

    private var agentColor: Color {
        let isDark = colorScheme == .dark
        switch session.agentType {
        case .claudeCode:
            return isDark ? Color(hex: "#E49F7D") : Color(hex: "#C66A45") // Coral/Apricot
        case .gemini:
            return isDark ? Color(hex: "#A8C7FA") : Color(hex: "#2563EB") // Cyan/Light Blue
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

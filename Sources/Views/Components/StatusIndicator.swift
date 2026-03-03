#if canImport(AppKit)
import SwiftUI

/// Color-coded status indicator dot with optional pulse animation.
struct StatusIndicator: View {
    let status: SessionStatus
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                shouldPulse
                    ? .easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                isPulsing = shouldPulse
            }
            .onChange(of: status) { _, _ in
                isPulsing = shouldPulse
            }
    }

    private var statusColor: Color {
        switch status {
        case .running:          .green
        case .thinking:         .blue
        case .waitingForUser:   .yellow
        case .idle:             .gray
        case .completed:        .blue
        case .error:            .red
        }
    }

    private var shouldPulse: Bool {
        status == .running || status == .thinking
    }

    private var pulseDuration: Double {
        status == .running ? 0.6 : 1.2
    }
}

/// Status icon with text label
struct StatusBadge: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        default:
            StatusIndicator(status: status)
        }
    }

    private var statusText: String {
        switch status {
        case .running:          "Running"
        case .thinking:         "Thinking"
        case .waitingForUser:   "Waiting"
        case .idle:             "Idle"
        case .completed:        "Completed"
        case .error:            "Error"
        }
    }
}
#endif

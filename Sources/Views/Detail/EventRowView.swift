#if canImport(AppKit)
import SwiftUI

/// A single event row in the timeline, expandable to show input/output details.
struct EventRowView: View {
    let event: AgentEvent
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed row
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(alignment: .top, spacing: 8) {
                    // Timestamp
                    Text(event.timeFormatted)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)

                    // Tool icon
                    Image(systemName: event.toolIcon)
                        .font(.caption)
                        .foregroundStyle(eventColor)
                        .frame(width: 16)

                    // Tool name + summary
                    VStack(alignment: .leading, spacing: 2) {
                        if let toolName = event.toolName {
                            Text(toolName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let summary = event.inputSummary {
                            Text(summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                    }

                    Spacer()

                    // Duration
                    if let duration = event.durationFormatted {
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let input = event.inputSummary, !input.isEmpty {
                DetailBox(title: "Input", content: input)
            }

            if let output = event.outputSummary, !output.isEmpty {
                DetailBox(title: "Output", content: output)
            }

            if event.tokensInput != nil || event.tokensOutput != nil {
                HStack {
                    TokenBadgeView(
                        inputTokens: event.tokensInput ?? 0,
                        outputTokens: event.tokensOutput ?? 0
                    )
                }
            }
        }
        .padding(.leading, 82)  // Align with tool icon
        .padding(.top, 4)
    }

    private var eventColor: Color {
        switch event.eventType {
        case .toolCall:       .green
        case .toolResult:     .blue
        case .message:        .secondary
        case .error:          .red
        case .subagentStart:  .purple
        case .subagentStop:   .purple
        }
    }
}

/// Monospace box for showing input/output details.
struct DetailBox: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(content)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(10)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
#endif

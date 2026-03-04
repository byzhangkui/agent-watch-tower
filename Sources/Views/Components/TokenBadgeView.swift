#if canImport(AppKit)
import SwiftUI

/// Compact token usage display.
struct TokenBadgeView: View {
    let inputTokens: Int
    let outputTokens: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatCount(inputTokens))
                .font(.caption2)
                .monospacedDigit()

            Text("·")
                .foregroundStyle(.quaternary)

            Image(systemName: "arrow.up.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatCount(outputTokens))
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
#endif

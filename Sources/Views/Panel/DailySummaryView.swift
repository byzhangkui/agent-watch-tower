#if canImport(AppKit)
import SwiftUI

/// Today's aggregate usage summary shown at the top of the panel.
struct DailySummaryView: View {
    let totalTokens: Int
    let estimatedCost: Double

    var body: some View {
        HStack {
            Label {
                Text("Today: \(formattedTokens) tokens")
                    .font(.caption)
            } icon: {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
            }

            Spacer()

            Text(CostCalculator.format(estimatedCost))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Constants.contentPadding)
        .padding(.vertical, 8)
    }

    private var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fk", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }
}
#endif

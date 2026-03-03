#if canImport(AppKit)
import SwiftUI

/// Horizontal bar chart showing tool usage distribution.
struct ToolUsageChartView: View {
    let toolUsage: [(tool: String, count: Int)]

    var body: some View {
        if !toolUsage.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Tool Usage")

                VStack(spacing: 6) {
                    ForEach(toolUsage, id: \.tool) { item in
                        ToolUsageRow(
                            toolName: item.tool,
                            count: item.count,
                            maxCount: toolUsage.first?.count ?? 1
                        )
                    }
                }
                .padding(Constants.contentPadding)
            }
        }
    }
}

struct ToolUsageRow: View {
    let toolName: String
    let count: Int
    let maxCount: Int

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(toolName)
                .font(.caption)
                .frame(width: 44, alignment: .trailing)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(toolColor)
                    .frame(width: geometry.size.width * ratio)
            }
            .frame(height: 12)

            Text("\(count)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var toolColor: Color {
        switch toolName {
        case "Edit":   Color(hex: "#8B5CF6")
        case "Read":   .blue
        case "Bash":   .green
        case "Write":  .orange
        case "Grep":   .cyan
        case "Glob":   .teal
        case "Agent":  .purple
        default:       .gray
        }
    }
}
#endif

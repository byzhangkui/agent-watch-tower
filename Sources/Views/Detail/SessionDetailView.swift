#if canImport(AppKit)
import SwiftUI

/// Detailed view for a single session with event timeline, tool usage, and token stats.
struct SessionDetailView: View {
    let viewModel: SessionDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, Constants.contentPadding)
                .padding(.vertical, 8)

                Divider()

                // Session header
                sessionHeader

                Divider()

                // Task progress
                TaskProgressView(
                    completed: viewModel.session.todoCompleted,
                    total: viewModel.session.todoTotal
                )

                // Event timeline
                EventTimelineView(events: viewModel.events)

                Divider()

                // Tool usage chart
                ToolUsageChartView(toolUsage: viewModel.toolUsage)

                Divider()

                // Token summary
                tokenSummary
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.reload()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StatusBadge(status: viewModel.session.status)

                Text(viewModel.session.agentType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: viewModel.session.agentType.brandColor))

                Spacer()

                Text(viewModel.session.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.session.projectDir)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let model = viewModel.session.model {
                Text(model)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let action = viewModel.session.currentAction {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                    Text(action)
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }
        }
        .padding(Constants.contentPadding)
    }

    @ViewBuilder
    private var tokenSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Tokens")

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Input")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCount(viewModel.totalTokensInput))
                            .font(.subheadline)
                            .monospacedDigit()
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCount(viewModel.totalTokensOutput))
                            .font(.subheadline)
                            .monospacedDigit()
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Est. Cost")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(CostCalculator.format(viewModel.estimatedCost))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(Constants.contentPadding)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
#endif

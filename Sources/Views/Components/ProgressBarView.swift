#if canImport(AppKit)
import SwiftUI

/// Animated progress bar showing task completion.
struct ProgressBarView: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress)
                        .animation(.easeInOut(duration: 0.15), value: progress)
                }
            }
            .frame(height: 6)

            Text("\(completed)/\(total) tasks")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return .green
        } else if progress > 0.5 {
            return .blue
        } else {
            return .orange
        }
    }
}
#endif

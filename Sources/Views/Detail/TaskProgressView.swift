#if canImport(AppKit)
import SwiftUI

/// Shows task progress from TodoWrite data.
struct TaskProgressView: View {
    let completed: Int?
    let total: Int?

    var body: some View {
        if let completed, let total, total > 0 {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Progress")

                VStack(alignment: .leading, spacing: 8) {
                    ProgressBarView(completed: completed, total: total)

                    Text("\(completed) of \(total) tasks completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Constants.contentPadding)
            }
        }
    }
}
#endif

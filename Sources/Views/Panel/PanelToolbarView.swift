#if canImport(AppKit)
import SwiftUI

/// Toolbar at the top of the panel with title and Pin button.
struct PanelToolbarView: View {
    let isPinned: Bool
    let onPin: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Text(Constants.appName)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onPin) {
                Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                    .font(.body)
                    .foregroundStyle(isPinned ? .blue : .secondary)
                    .rotationEffect(.degrees(isPinned ? 0 : 45))
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin from screen" : "Pin as floating window")
        }
        .padding(.horizontal, Constants.contentPadding)
        .padding(.vertical, 8)
    }
}
#endif

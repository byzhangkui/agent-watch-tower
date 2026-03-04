#if canImport(AppKit)
import SwiftUI

/// Toolbar at the top of the panel with title and action buttons.
struct PanelToolbarView: View {
    let onOpenWindow: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Text(Constants.appName)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button(action: {
                #if canImport(AppKit)
                NSApp.terminate(nil)
                #endif
            }) {
                Image(systemName: "power")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Application")

            Button(action: onOpenWindow) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open as window")
        }
        .padding(.horizontal, Constants.contentPadding)
        .padding(.vertical, 8)
    }
}
#endif

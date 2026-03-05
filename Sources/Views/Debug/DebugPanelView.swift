#if canImport(AppKit)
import SwiftUI
import Observation

/// View model to capture and hold recent hook events for debugging.
@Observable
@MainActor
final class DebugViewModel {
    static let shared = DebugViewModel()
    
    struct LogEntry: Identifiable, Hashable {
        let id = UUID()
        let timestamp: Date
        let eventName: String
        let summary: String
        let rawJson: String
    }
    
    var logs: [LogEntry] = []
    
    private init() {}
    
    func addLog(eventName: String, summary: String, rawJson: String) {
        let entry = LogEntry(
            timestamp: Date(),
            eventName: eventName,
            summary: summary,
            rawJson: rawJson
        )
        // Keep last 100 entries to avoid memory bloat
        if logs.count >= 100 {
            logs.removeLast()
        }
        logs.insert(entry, at: 0)
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}

/// A developer debug panel to monitor incoming HTTP hook payloads in real-time.
struct DebugPanelView: View {
    @Bindable private var viewModel = DebugViewModel.shared
    @State private var selectedLog: DebugViewModel.LogEntry?
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.logs, selection: $selectedLog) { log in
                VStack(alignment: .leading) {
                    Text(log.eventName)
                        .font(.headline)
                        .foregroundStyle(colorForEvent(log.eventName))
                    Text(log.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(log.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .tag(log)
            }
            .navigationTitle("Recent Hooks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.clearLogs() }) {
                        Image(systemName: "trash")
                    }
                    .help("Clear logs")
                }
            }
        } detail: {
            if let log = selectedLog {
                ScrollView {
                    Text(log.rawJson)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(log.eventName)
            } else {
                Text("Select an event to view raw payload")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func colorForEvent(_ event: String) -> Color {
        switch event {
        case "SessionStart", "BeforeAgent": return .green
        case "SessionEnd", "Stop": return .red
        case "BeforeTool", "PreToolUse": return .blue
        case "AfterTool", "PostToolUse": return .purple
        default: return .primary
        }
    }
}
#endif

import Foundation

/// Routes incoming hook events to the EventProcessor.
/// Handles JSON decoding and dispatches to the appropriate handler.
final class EventRouter: Sendable {
    private let processor: EventProcessor

    init(processor: EventProcessor) {
        self.processor = processor
    }

    /// Handle raw HTTP body data from a hook event.
    func handle(_ data: Data) {
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        do {
            let payload = try JSONDecoder().decode(HookPayload.self, from: data)
            let summary = "Session: \(payload.sessionId)\nAgent: \(payload.agentName ?? "Unknown")"
            
            Task { @MainActor in
                #if DEBUG
                DebugViewModel.shared.addLog(
                    eventName: payload.hookEventName,
                    summary: summary,
                    rawJson: jsonString
                )
                #endif
            }
            
            Task {
                await processor.process(payload)
            }
        } catch {
            print("Failed to decode hook payload: \(error)")
            
            Task { @MainActor in
                #if DEBUG
                DebugViewModel.shared.addLog(
                    eventName: "Decode Error",
                    summary: error.localizedDescription,
                    rawJson: jsonString
                )
                #endif
            }
        }
    }
}

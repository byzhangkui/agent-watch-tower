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
        print("EventRouter: Received hook payload (\(data.count) bytes)")
        do {
            let payload = try JSONDecoder().decode(HookPayload.self, from: data)
            print("EventRouter: Decoded payload for session: \(payload.sessionId) - event: \(payload.hookEventName)")
            Task {
                await processor.process(payload)
            }
        } catch {
            print("Failed to decode hook payload: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw payload: \(jsonString)")
            }
        }
    }
}

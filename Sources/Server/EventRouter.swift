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
        guard let payload = try? JSONDecoder().decode(HookPayload.self, from: data) else {
            return
        }
        Task {
            await processor.process(payload)
        }
    }
}

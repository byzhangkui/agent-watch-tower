import Foundation
import Swifter

/// Embedded HTTP server that receives Claude Code hook events.
final class EventServer {
    private let server = HttpServer()
    private let port: UInt16
    private let eventRouter: EventRouter

    init(eventRouter: EventRouter, port: UInt16 = Constants.httpPort) {
        self.eventRouter = eventRouter
        self.port = port
        setupRoutes()
    }

    private func setupRoutes() {
        // Unified event endpoint
        server.POST["/events"] = { [weak self] request in
            let body = Data(request.body)
            self?.eventRouter.handle(body)
            return .ok(.json([String: String]()))
        }

        // Per-event-type endpoints for structured hook configuration
        let eventPaths = [
            "user-prompt-submit",
            "pre-tool-use", "post-tool-use", "notification",
            "session-start", "stop",
            "subagent-start", "subagent-stop"
        ]

        for path in eventPaths {
            server.POST["/events/\(path)"] = { [weak self] request in
                let body = Data(request.body)
                self?.eventRouter.handle(body)
                return .ok(.json([String: String]()))
            }
        }

        // Health check
        server.GET["/health"] = { _ in
            .ok(.text("{\"status\":\"running\"}"))
        }
    }

    func start() throws {
        try server.start(port, forceIPv4: true, priority: .default)
    }

    func stop() {
        server.stop()
    }

    var isRunning: Bool {
        server.state == .running
    }
}

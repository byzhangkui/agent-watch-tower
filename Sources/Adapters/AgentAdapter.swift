import Foundation

/// Protocol for adapting agent-specific events into unified models.
/// Implement this protocol for each supported agent type (Claude Code, Gemini, etc.).
protocol AgentAdapter {
    var agentType: AgentType { get }

    /// Convert a hook payload into a unified AgentEvent.
    func parseEvent(from payload: HookPayload) -> AgentEvent?

    /// Create or update a session from a hook payload.
    func updateSession(from payload: HookPayload, existing: AgentSession?) -> AgentSession

    /// Extract a human-readable action description from a tool payload.
    func describeAction(from payload: HookPayload) -> String?
}

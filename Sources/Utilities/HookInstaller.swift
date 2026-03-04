import Foundation

struct HookInstaller {
    static let claudeHookRoutes: [(event: String, path: String)] = [
        ("UserPromptSubmit", "/events/user-prompt-submit"),
        ("PreToolUse",    "/events/pre-tool-use"),
        ("PostToolUse",   "/events/post-tool-use"),
        ("Notification",  "/events/notification"),
        ("SessionStart",  "/events/session-start"),
        ("Stop",          "/events/stop"),
        ("SubagentStart", "/events/subagent-start"),
        ("SubagentStop",  "/events/subagent-stop"),
    ]
    
    static let geminiHookEvents = [
        "SessionStart", "SessionEnd", "BeforeTool", "AfterTool", "BeforeAgent", "AfterAgent"
    ]

    /// Install HTTP hooks into both ~/.claude/settings.json and ~/.gemini/settings.json
    static func install(port: UInt16 = Constants.httpPort) throws {
        try installClaudeHooks(port: port)
        try installGeminiHooks(port: port)
    }

    /// Remove Watch Tower hooks from both tools
    static func uninstall(port: UInt16 = Constants.httpPort) throws {
        try uninstallClaudeHooks(port: port)
        try uninstallGeminiHooks(port: port)
    }

    /// Check if hooks are currently installed in *both* tools (or at least partially)
    static func isInstalled(port: UInt16 = Constants.httpPort) -> Bool {
        return isClaudeInstalled(port: port) || isGeminiInstalled(port: port)
    }

    // MARK: - Claude Code Hooks

    private static func installClaudeHooks(port: UInt16) throws {
        var settings = try readExistingSettings(at: Constants.claudeSettingsPath)

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for route in claudeHookRoutes {
            let hookEntry: [String: Any] = [
                "type": "http",
                "url": "http://localhost:\(port)\(route.path)",
                "timeout": 5
            ]
            let matcherEntry: [String: Any] = [
                "matcher": "",
                "hooks": [hookEntry]
            ]

            var existing = hooks[route.event] as? [[String: Any]] ?? []

            let alreadyInstalled = existing.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["url"] as? String)?.contains("localhost:\(port)") == true
                }
            }

            if !alreadyInstalled {
                existing.append(matcherEntry)
            }
            hooks[route.event] = existing
        }

        settings["hooks"] = hooks
        try writeSettings(settings, to: Constants.claudeSettingsPath)
    }

    private static func uninstallClaudeHooks(port: UInt16) throws {
        var settings = try readExistingSettings(at: Constants.claudeSettingsPath)

        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for route in claudeHookRoutes {
            guard var entries = hooks[route.event] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["url"] as? String)?.contains("localhost:\(port)") == true
                }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: route.event)
            } else {
                hooks[route.event] = entries
            }
        }

        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try writeSettings(settings, to: Constants.claudeSettingsPath)
    }

    private static func isClaudeInstalled(port: UInt16) -> Bool {
        guard let settings = try? readExistingSettings(at: Constants.claudeSettingsPath),
              let hooks = settings["hooks"] as? [String: Any] else {
            return false
        }

        for route in claudeHookRoutes {
            guard let entries = hooks[route.event] as? [[String: Any]] else { continue }
            let found = entries.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["url"] as? String)?.contains("localhost:\(port)") == true
                }
            }
            if found { return true }
        }

        return false
    }

    // MARK: - Gemini CLI Hooks

    private static func installGeminiHooks(port: UInt16) throws {
        var settings = try readExistingSettings(at: Constants.geminiSettingsPath)

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let curlCommand = "curl -s -X POST -H \"Content-Type: application/json\" -d @- http://localhost:\(port)/events > /dev/null && echo '{}'"

        for eventName in geminiHookEvents {
            let hookEntry: [String: Any] = [
                "name": "send-to-watch-tower",
                "type": "command",
                "command": curlCommand
            ]
            let matcherEntry: [String: Any] = [
                "matcher": "*",
                "hooks": [hookEntry]
            ]

            var existing = hooks[eventName] as? [[String: Any]] ?? []

            let alreadyInstalled = existing.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["name"] as? String) == "send-to-watch-tower"
                }
            }

            if !alreadyInstalled {
                existing.append(matcherEntry)
            }
            hooks[eventName] = existing
        }

        settings["hooks"] = hooks
        try writeSettings(settings, to: Constants.geminiSettingsPath)
    }

    private static func uninstallGeminiHooks(port: UInt16) throws {
        var settings = try readExistingSettings(at: Constants.geminiSettingsPath)

        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for eventName in geminiHookEvents {
            guard var entries = hooks[eventName] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["name"] as? String) == "send-to-watch-tower"
                }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = entries
            }
        }

        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try writeSettings(settings, to: Constants.geminiSettingsPath)
    }

    private static func isGeminiInstalled(port: UInt16) -> Bool {
        guard let settings = try? readExistingSettings(at: Constants.geminiSettingsPath),
              let hooks = settings["hooks"] as? [String: Any] else {
            return false
        }

        for eventName in geminiHookEvents {
            guard let entries = hooks[eventName] as? [[String: Any]] else { continue }
            let found = entries.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["name"] as? String) == "send-to-watch-tower"
                }
            }
            if found { return true }
        }

        return false
    }

    // MARK: - Private

    private static func readExistingSettings(at path: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }
        let data = try Data(contentsOf: path)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func writeSettings(_ settings: [String: Any], to path: URL) throws {
        // Ensure parent directory exists
        let dir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: path, options: .atomic)
    }
}

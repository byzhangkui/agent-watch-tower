import Foundation

struct HookInstaller {
    static let hookRoutes: [(event: String, path: String)] = [
        ("PreToolUse",    "/events/pre-tool-use"),
        ("PostToolUse",   "/events/post-tool-use"),
        ("Notification",  "/events/notification"),
        ("SessionStart",  "/events/session-start"),
        ("Stop",          "/events/stop"),
        ("SubagentStart", "/events/subagent-start"),
        ("SubagentStop",  "/events/subagent-stop"),
    ]

    /// Install HTTP hooks into ~/.claude/settings.json
    static func install(port: UInt16 = Constants.httpPort) throws {
        var settings = try readExistingSettings()

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for route in hookRoutes {
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

            // Check if already installed to avoid duplicates
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
        try writeSettings(settings)
    }

    /// Remove Watch Tower hooks from ~/.claude/settings.json
    static func uninstall(port: UInt16 = Constants.httpPort) throws {
        var settings = try readExistingSettings()

        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for route in hookRoutes {
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
        try writeSettings(settings)
    }

    /// Check if hooks are currently installed
    static func isInstalled(port: UInt16 = Constants.httpPort) -> Bool {
        guard let settings = try? readExistingSettings(),
              let hooks = settings["hooks"] as? [String: Any] else {
            return false
        }

        // Check if at least one of our hooks exists
        for route in hookRoutes {
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

    // MARK: - Private

    private static func readExistingSettings() throws -> [String: Any] {
        let path = Constants.claudeSettingsPath
        guard FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }
        let data = try Data(contentsOf: path)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let path = Constants.claudeSettingsPath

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

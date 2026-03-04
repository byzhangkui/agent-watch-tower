import Foundation

enum Constants {
    static let httpPort: UInt16 = 19280
    static let appName = "Agent Watch Tower"
    static let bundleIdentifier = "com.agentwatchtower.app"

    // Window sizing
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 500
    static let panelMinWidth: CGFloat = 280
    static let panelMinHeight: CGFloat = 300
    static let panelMaxWidth: CGFloat = 480
    static let panelMaxHeight: CGFloat = 800
    static let panelDefaultWidth: CGFloat = 320
    static let panelDefaultHeight: CGFloat = 420

    // UI
    static let cardCornerRadius: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let contentPadding: CGFloat = 12
    static let windowCornerRadius: CGFloat = 10

    // Data
    static let defaultRetentionDays = 30

    // Paths
    static var databaseDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("AgentWatchTower")
        try? FileManager.default.createDirectory(
            at: appSupport, withIntermediateDirectories: true
        )
        return appSupport
    }

    static var databasePath: String {
        databaseDirectory.appendingPathComponent("watchtower.sqlite").path
    }

    static var claudeSettingsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static var geminiSettingsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/settings.json")
    }
}

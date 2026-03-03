#if canImport(AppKit)
import SwiftUI

@main
struct AgentWatchTowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
#else
// Stub entry point for non-macOS platforms (e.g., Linux CI)
@main
struct AgentWatchTowerApp {
    static func main() {
        print("Agent Watch Tower requires macOS 14+")
    }
}
#endif

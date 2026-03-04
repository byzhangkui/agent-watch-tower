#if canImport(AppKit)
import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var claudeHooksInstalled: Bool = false
    var geminiHooksInstalled: Bool = false
    var serverRunning: Bool = false
    var retentionDays: Int = Constants.defaultRetentionDays
    var showInstallAlert: Bool = false
    var alertMessage: String = ""

    init() {
        checkHookStatus()
    }

    func checkHookStatus() {
        claudeHooksInstalled = HookInstaller.isClaudeInstalled()
        geminiHooksInstalled = HookInstaller.isGeminiInstalled()
    }

    func installClaudeHooks() {
        do {
            try HookInstaller.installClaudeHooks(port: Constants.httpPort)
            claudeHooksInstalled = true
            alertMessage = "Claude Code hooks installed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to install Claude Code hooks: \(error.localizedDescription)"
            showInstallAlert = true
        }
    }

    func uninstallClaudeHooks() {
        do {
            try HookInstaller.uninstallClaudeHooks(port: Constants.httpPort)
            claudeHooksInstalled = false
            alertMessage = "Claude Code hooks removed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to remove Claude Code hooks: \(error.localizedDescription)"
            showInstallAlert = true
        }
    }
    
    func installGeminiHooks() {
        do {
            try HookInstaller.installGeminiHooks(port: Constants.httpPort)
            geminiHooksInstalled = true
            alertMessage = "Gemini CLI hooks installed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to install Gemini CLI hooks: \(error.localizedDescription)"
            showInstallAlert = true
        }
    }

    func uninstallGeminiHooks() {
        do {
            try HookInstaller.uninstallGeminiHooks(port: Constants.httpPort)
            geminiHooksInstalled = false
            alertMessage = "Gemini CLI hooks removed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to remove Gemini CLI hooks: \(error.localizedDescription)"
            showInstallAlert = true
        }
    }

    func testConnection() {
        let url = URL(string: "http://localhost:\(Constants.httpPort)/health")!
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.serverRunning = true
                    self?.alertMessage = "Connection successful! Server is running."
                } else {
                    self?.serverRunning = false
                    self?.alertMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
                }
                self?.showInstallAlert = true
            }
        }
        task.resume()
    }
}
#endif

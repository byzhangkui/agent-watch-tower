#if canImport(AppKit)
import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var hooksInstalled: Bool = false
    var serverRunning: Bool = false
    var retentionDays: Int = Constants.defaultRetentionDays
    var showInstallAlert: Bool = false
    var alertMessage: String = ""

    init() {
        checkHookStatus()
    }

    func checkHookStatus() {
        hooksInstalled = HookInstaller.isInstalled()
    }

    func installHooks() {
        do {
            try HookInstaller.install()
            hooksInstalled = true
            alertMessage = "Hooks installed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to install hooks: \(error.localizedDescription)"
            showInstallAlert = true
        }
    }

    func uninstallHooks() {
        do {
            try HookInstaller.uninstall()
            hooksInstalled = false
            alertMessage = "Hooks removed successfully."
            showInstallAlert = true
        } catch {
            alertMessage = "Failed to remove hooks: \(error.localizedDescription)"
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

#if canImport(AppKit)
import AppKit
import Combine

/// Manages the NSStatusItem in the macOS menu bar.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var animationTimer: Timer?
    private var pulsePhase: CGFloat = 0
    private var onToggle: (() -> Void)?

    enum IconState {
        case idle
        case running(Int)   // count of active agents
        case error
    }

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right",
                accessibilityDescription: Constants.appName
            )
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
    }

    var button: NSStatusBarButton? {
        statusItem.button
    }

    func updateIcon(_ state: IconState) {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle:
            stopAnimation()
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right",
                accessibilityDescription: "Idle"
            )
            button.title = ""
            button.contentTintColor = .secondaryLabelColor

        case .running(let count):
            startPulseAnimation()
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right",
                accessibilityDescription: "Running"
            )
            button.title = count > 0 ? " \(count)" : ""
            button.contentTintColor = .controlAccentColor

        case .error:
            stopAnimation()
            button.image = NSImage(
                systemSymbolName: "antenna.radiowaves.left.and.right.slash",
                accessibilityDescription: "Error"
            )
            button.title = ""
            button.contentTintColor = .systemRed
        }
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked() {
        onToggle?()
    }

    // MARK: - Animation

    private func startPulseAnimation() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            self.pulsePhase += 0.05
            let alpha = 0.5 + 0.5 * sin(self.pulsePhase * .pi)
            button.alphaValue = CGFloat(alpha)
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        statusItem.button?.alphaValue = 1.0
    }

    deinit {
        stopAnimation()
    }
}
#endif

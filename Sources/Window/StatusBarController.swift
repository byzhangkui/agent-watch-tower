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
            button.image = getMenuIcon()
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
    }

    var button: NSStatusBarButton? {
        statusItem.button
    }
    
    private func getMenuIcon(isError: Bool = false) -> NSImage? {
        let name = "menubar-iconTemplate"
        var image = NSImage(named: name)
        
        if image == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "png") {
                image = NSImage(contentsOf: url)
            } else {
                let pngPath = FileManager.default.currentDirectoryPath + "/Resources/\(name).png"
                if FileManager.default.fileExists(atPath: pngPath) {
                    image = NSImage(contentsOfFile: pngPath)
                }
            }
        }
        
        if let image = image {
            let copy = image.copy() as! NSImage
            copy.setName(NSImage.Name(name))
            copy.isTemplate = true
            copy.size = NSSize(width: 18, height: 18)
            return copy
        }
        
        let fallback = NSImage(
            systemSymbolName: isError ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right",
            accessibilityDescription: Constants.appName
        )
        fallback?.isTemplate = true
        return fallback
    }

    func updateIcon(_ state: IconState) {
        guard let button = statusItem.button else { return }

        switch state {
        case .idle:
            stopAnimation()
            button.image = getMenuIcon()
            button.title = ""
            button.contentTintColor = nil   // let system handle adaptive rendering

        case .running(let count):
            stopAnimation()
            button.image = getMenuIcon()
            button.title = count > 0 ? " \(count)" : ""
            button.contentTintColor = .controlAccentColor

        case .error:
            stopAnimation()
            button.image = getMenuIcon(isError: true)
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

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var windowObserver: NSObjectProtocol?
    private lazy var runtimeIcon: NSImage? = resolvedRuntimeIcon()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        observeWindowIcons()

        // Wait one run-loop turn so the status button and first window both exist.
        DispatchQueue.main.async { [weak self] in
            self?.applyDockIcon()
            self?.applyMenuBarIcon()
            self?.applyMiniwindowIconsToOpenWindows()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
    }

    // MARK: - Dock / application icon (Surface 3)

    private func applyDockIcon() {
        guard let img = runtimeIcon else { return }
        NSApplication.shared.applicationIconImage = img
    }

    /// Resolution order: AppIconRuntime.png → AppIcon.icns → raw master PNG.
    private func resolvedRuntimeIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIconRuntime", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let masterURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("vault-verse.png")
        return NSImage(contentsOf: masterURL)
    }

    // MARK: - Menu bar status icon (Surface 1)

    private func applyMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let btn = statusItem?.button else { return }
        if let image = buildMenuBarImage() {
            btn.image = image
            btn.imageScaling = .scaleProportionallyDown
        }
    }

    /// Builds a dual-rep NSImage (22×22 logical points) from the 1× and 2× PNGs.
    /// The 2× rep is added first so AppKit picks the highest-resolution representation
    /// on Retina displays without any extra work.
    private func buildMenuBarImage() -> NSImage? {
        guard
            let path1x = Bundle.main.path(forResource: "menubar",    ofType: "png"),
            let path2x = Bundle.main.path(forResource: "menubar@2x", ofType: "png"),
            let data1x = try? Data(contentsOf: URL(fileURLWithPath: path1x)),
            let data2x = try? Data(contentsOf: URL(fileURLWithPath: path2x)),
            let rep1x  = NSBitmapImageRep(data: data1x),
            let rep2x  = NSBitmapImageRep(data: data2x)
        else { return nil }

        // Both reps must claim 22×22 logical points regardless of pixel count.
        let logicalSize = NSSize(width: 22, height: 22)
        rep1x.size = logicalSize
        rep2x.size = logicalSize

        let image = NSImage(size: logicalSize)
        image.addRepresentation(rep2x) // 2× first
        image.addRepresentation(rep1x)
        image.isTemplate = false       // keep full color
        return image
    }

    // MARK: - Miniwindow icon (Surface 3 companion)

    private func observeWindowIcons() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.applyMiniwindowIcon(to: window)
        }
    }

    private func applyMiniwindowIconsToOpenWindows() {
        NSApplication.shared.windows.forEach(applyMiniwindowIcon(to:))
    }

    private func applyMiniwindowIcon(to window: NSWindow) {
        guard let img = runtimeIcon else { return }
        window.miniwindowImage = img
    }
}

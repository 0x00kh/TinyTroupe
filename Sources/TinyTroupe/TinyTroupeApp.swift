import AppKit

@main
@MainActor
private enum TinyTroupeApp {
    static func main() {
        let application = NSApplication.shared
        _ = application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runnerManager: RunnerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        runnerManager = RunnerManager()
    }
}

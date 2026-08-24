import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = PowerMonitor()
    private var didStart = false
    private var statusItemController: StatusItemController?

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        monitor.start()
        statusItemController = StatusItemController(monitor: monitor)
        if CommandLine.arguments.contains("--smoke-launch") {
            scheduleSmokeLaunchCheck()
        }
    }

    /// Automated launch check: fail if a content window appeared (the old flash).
    private func scheduleSmokeLaunchCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard self != nil else { exit(1) }
            let visible = NSApp.windows.filter(\.isVisible)
            let leaked = visible.filter { window in
                let title = window.title
                if title.contains("Details") { return true }
                // Status item's button window is tiny; a leaked panel is not.
                return window.frame.width >= 200 && window.frame.height >= 80
            }
            if leaked.isEmpty {
                fputs("smoke-launch OK: no content window at launch\n", stderr)
                exit(0)
            } else {
                let desc = leaked.map { "\($0.title) \($0.frame.size)" }.joined(separator: "; ")
                fputs("smoke-launch FAIL: visible windows: \(desc)\n", stderr)
                exit(1)
            }
        }
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            startIfNeeded()
        }
    }

    nonisolated func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            monitor.refreshNow()
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            statusItemController?.invalidate()
            statusItemController = nil
            monitor.stop()
        }
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct PowerTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI requires a Scene. Window/Settings present at launch (the flash).
        // A MenuBarExtra with isInserted=false is not shown; the real extra is AppKit.
        MenuBarExtra(isInserted: .constant(false)) {
            EmptyView()
        } label: {
            EmptyView()
        }
    }
}
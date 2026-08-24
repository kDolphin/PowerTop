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
        hideDetailWindowAtLaunch()
        DispatchQueue.main.async { [weak self] in
            self?.hideDetailWindowAtLaunch()
        }
    }

    private func hideDetailWindowAtLaunch() {
        let detailTitle = String(localized: "PowerTop Details")
        for window in NSApp.windows where window.title == detailTitle {
            window.isReleasedWhenClosed = false
            window.orderOut(nil)
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
}

@main
struct PowerTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    private var monitor: PowerMonitor { appDelegate.monitor }

    var body: some Scene {
        Window(String(localized: "PowerTop Details"), id: "detail") {
            DetailWindowView(monitor: monitor)
                .onReceive(NotificationCenter.default.publisher(for: .powerTopOpenDetails)) { _ in
                    openWindow(id: "detail")
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: DetailWindowView.preferredWidth, height: 640)
        .windowResizability(.contentSize)
    }
}
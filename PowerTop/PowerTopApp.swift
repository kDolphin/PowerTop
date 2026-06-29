import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = PowerMonitor()
    private var didStart = false

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        monitor.start()
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
            monitor.stop()
        }
    }
}

@main
struct PowerTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var monitor: PowerMonitor { appDelegate.monitor }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabelView(monitor: monitor)
                .id(monitor.uiRefreshToken)
        }
        .menuBarExtraStyle(.window)

        Window(String(localized: "PowerTop Details"), id: "detail") {
            DetailWindowView(monitor: monitor)
                .frame(minWidth: 520, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 560, height: 640)
    }
}
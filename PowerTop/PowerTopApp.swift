import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: PowerMonitor?

    @MainActor
    func bind(monitor: PowerMonitor) {
        guard self.monitor == nil else { return }
        self.monitor = monitor
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            monitor?.stop()
        }
    }
}

@main
struct PowerTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
                .task { appDelegate.bind(monitor: monitor) }
        } label: {
            MenuBarLabelView(
                data: monitor.currentData,
                showPower: monitor.showPowerInMenuBar,
                isDataAvailable: monitor.isDataAvailable
            )
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
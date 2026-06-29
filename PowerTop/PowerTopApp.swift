import SwiftUI

@main
struct PowerTopApp: App {
    @State private var monitor = PowerMonitor()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabelView(
                data: monitor.currentData,
                showPower: monitor.showPowerInMenuBar
            )
        }
        .menuBarExtraStyle(.window)

        Window(String(localized: "PowerTop Details"), id: "detail") {
            DetailWindowView(monitor: monitor)
                .frame(minWidth: 520, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 560, height: 640)

        Settings {
            EmptyView()
        }
    }

    init() {
        monitor.start()
    }
}

import SwiftUI

struct MenuBarLabelView: View {
    let monitor: PowerMonitor

    private var data: PowerData { monitor.currentData }
    private var showPower: Bool { monitor.showPowerInMenuBar }
    private var isDataAvailable: Bool { monitor.isDataAvailable }

    var body: some View {
        if !isDataAvailable {
            Image(systemName: "exclamationmark.triangle")
        } else if showPower {
            Text(data.menuBarPowerText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(
                    width: data.menuBarPowerShowsWarning ? Self.warningPowerTextWidth : Self.powerTextWidth,
                    alignment: .trailing
                )
        } else {
            Image(systemName: data.effectiveIsOnAC ? "bolt.fill" : "battery.50")
        }
    }

    static let powerTextWidth: CGFloat = 30
    static let warningPowerTextWidth: CGFloat = 46

    static func preferredWidth(for monitor: PowerMonitor) -> CGFloat {
        if !monitor.isDataAvailable { return 22 }
        if monitor.showPowerInMenuBar {
            return monitor.currentData.menuBarPowerShowsWarning ? warningPowerTextWidth : powerTextWidth
        }
        return 22
    }
}
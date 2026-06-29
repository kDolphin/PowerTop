import SwiftUI

struct MenuBarLabelView: View {
    let data: PowerData
    let showPower: Bool
    let isDataAvailable: Bool

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

    private static let powerTextWidth: CGFloat = 30
    private static let warningPowerTextWidth: CGFloat = 46
}
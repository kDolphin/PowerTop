import SwiftUI

struct MenuBarLabelView: View {
    let data: PowerData
    let showPower: Bool

    var body: some View {
        if showPower {
            Text(data.menuBarPowerText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(powerTextColor)
                .frame(width: Self.powerTextWidth, alignment: .trailing)
        } else {
            Image(systemName: data.isOnAC ? "bolt.fill" : "battery.50")
        }
    }

    private static let powerTextWidth: CGFloat = 30

    private var powerTextColor: Color {
        if data.menuBarPowerShowsBatteryWarning { return .red }
        if data.menuBarPowerExceedsCap { return .orange }
        return .primary
    }
}
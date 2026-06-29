import SwiftUI

struct DetailWindowView: View {
    let monitor: PowerMonitor

    private var data: PowerData { monitor.currentData }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                powerSection
                batteryHealthSection
                if hasCellData { cellDataSection }
                chargingSection
                if hasLifetimeData { lifetimeSection }
                if hasDeviceInfo { deviceInfoSection }
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 500)
        .background(.windowBackground)
    }

    private var hasCellData: Bool {
        data.cellVoltagesMV != nil
            || data.qmaxMAH != nil
            || (data.dailyMinSoc != nil && data.dailyMaxSoc != nil)
    }

    private var hasLifetimeData: Bool {
        data.totalOperatingTimeMin != nil
            || data.lifetimeMaxTempC != nil
            || data.lifetimeMinTempC != nil
            || data.lifetimeAvgTempC != nil
            || data.lifetimeMaxPackVoltageMV != nil
            || data.lifetimeMinPackVoltageMV != nil
            || data.lifetimeMaxChargeCurrentMA != nil
            || data.lifetimeMaxDischargeCurrentMA != nil
            || data.batteryCellDisconnectCount != nil
    }

    private var hasDeviceInfo: Bool {
        data.batterySerial != nil || data.deviceName != nil
    }

    // MARK: - Power

    private var powerSection: some View {
        DetailSection(title: String(localized: "Power"), icon: "bolt.fill", color: .green) {
            DetailRow(label: String(localized: "Power Source"), value: data.powerSourceDescription)
            DetailRow(label: String(localized: "Total System Power (Instant)"), value: String(format: "%.1f W", data.systemPowerW), highlight: true)
            if data.effectiveIsOnAC {
                DetailRow(label: String(localized: "AC Adapter Total Output (DC)"), value: String(format: "%.1f W", data.effectiveACOutputW))
            }
            if data.batteryPowerW != 0 {
                DetailRow(
                    label: data.isBatteryCharging ? String(localized: "Battery Charging Power") : String(localized: "Battery Discharging Power"),
                    value: String(format: "%.1f W", abs(data.batteryPowerW))
                )
            }
            if data.effectiveIsOnAC && data.acAdapterWattage > 0 {
                DetailRow(label: String(localized: "Charger Rated Power"), value: "\(data.acAdapterWattage) W" + (data.adapterDescription.map { " (\($0))" } ?? ""))
                let usage = data.acAdapterWattage > 0 ? data.effectiveACOutputW / Double(data.acAdapterWattage) * 100 : 0
                DetailRow(label: String(localized: "Charger Load Rate"), value: String(format: "%.0f%%", usage), bar: (min(usage, 100), 100))
            }
            if let wall = data.wallPowerW {
                DetailRow(label: String(localized: "Avg Wall Outlet Power (Long-term)"), value: String(format: "%.1f W", wall))
            }
            if let loss = data.adapterEfficiencyLossW {
                DetailRow(label: String(localized: "Avg Adapter Loss (Long-term)"), value: String(format: "%.1f W", loss))
            }
            if let sv = data.systemVoltageMV {
                DetailRow(label: String(localized: "Charger Output Voltage"), value: String(format: "%.2f V", Double(sv) / 1000.0))
            }
            if let sc = data.systemCurrentMA {
                DetailRow(label: String(localized: "Charger Output Current"), value: String(format: "%.3f A", Double(sc) / 1000.0))
            }
            if data.dataSource == .legacy {
                DetailRow(label: String(localized: "Data Source"), value: String(localized: "Estimation Mode (No PowerTelemetryData)"))
            }
        }
    }

    // MARK: - Battery Health

    private var batteryHealthSection: some View {
        DetailSection(title: String(localized: "Battery Health"), icon: "heart.fill", color: healthColor) {
            if let health = data.batteryHealthPercent {
                DetailRow(label: String(localized: "Max Capacity (Health)"), value: "\(health)%", highlight: true, bar: (Double(health), 100))
            }
            if let design = data.designCapacityMAH {
                DetailRow(label: String(localized: "Design Capacity"), value: "\(design) mAh")
            }
            if let raw = data.rawMaxCapacityMAH {
                DetailRow(label: String(localized: "Full Charge Capacity (FCC)"), value: "\(raw) mAh")
            }
            if let nom = data.nominalChargeCapacityMAH {
                DetailRow(label: String(localized: "Nominal Full Charge Capacity"), value: "\(nom) mAh")
            }
            if let cycles = data.cycleCount, let designCycles = data.designCycleCount {
                DetailRow(label: String(localized: "Cycle Count"), value: "\(cycles) / \(designCycles) (\(String(localized: "design life")))", bar: (Double(cycles), Double(designCycles)))
            } else if let cycles = data.cycleCount {
                DetailRow(label: String(localized: "Cycle Count"), value: "\(cycles)")
            }
            if let soc = data.stateOfCharge {
                DetailRow(label: String(localized: "Battery Level (Cell Precise)"), value: "\(soc)%")
            } else {
                DetailRow(label: String(localized: "Battery Level"), value: "\(data.batteryPercent)%")
            }
            if let temp = data.batteryTemperatureC {
                DetailRow(label: String(localized: "Battery Temp"), value: String(format: "%.1f °C", temp))
            }
            if let voltage = data.batteryVoltageMV {
                DetailRow(label: String(localized: "Battery Pack Voltage"), value: String(format: "%.2f V", Double(voltage) / 1000.0))
            }
            if let amp = data.batteryAmperageMA {
                let sign = amp > 0 ? String(localized: "Discharging") : (amp < 0 ? String(localized: "Charging") : String(localized: "Idle"))
                DetailRow(label: String(localized: "Battery Current"), value: String(format: "%d mA (%@)", abs(amp), sign))
            }
            if let instant = data.instantAmperageMA {
                DetailRow(label: String(localized: "Battery Instant Current"), value: String(format: "%d mA", instant))
            }
            if let critical = data.atCriticalLevel {
                DetailRow(label: String(localized: "Critical Low Battery"), value: critical ? String(localized: "Yes") : String(localized: "No"))
            }
            if let failure = data.permanentFailureStatus {
                DetailRow(label: String(localized: "Permanent Failure Status"), value: failure == 0 ? String(localized: "Normal") : String(format: String(localized: "Abnormal (%d)"), failure))
            }
        }
    }

    private var healthColor: Color {
        guard let h = data.batteryHealthPercent else { return .secondary }
        if h >= 80 { return .green }
        if h >= 60 { return .orange }
        return .red
    }

    // MARK: - Cell Data

    private var cellDataSection: some View {
        DetailSection(title: String(localized: "Cell Data"), icon: "cylinder.split.1.raised", color: .cyan) {
            if let cells = data.cellVoltagesMV {
                ForEach(Array(cells.enumerated()), id: \.offset) { idx, mv in
                    DetailRow(label: String(format: String(localized: "Cell %d Voltage"), idx + 1), value: String(format: "%.3f V", Double(mv) / 1000.0))
                }
            }
            if let qmax = data.qmaxMAH {
                ForEach(Array(qmax.enumerated()), id: \.offset) { idx, mah in
                    DetailRow(label: String(format: String(localized: "Cell %d Full Charge Capacity"), idx + 1), value: "\(mah) mAh")
                }
            }
            if let minSoc = data.dailyMinSoc, let maxSoc = data.dailyMaxSoc {
                DetailRow(label: String(localized: "Optimized Charging Range"), value: "\(minSoc)% - \(maxSoc)%")
            }
        }
    }

    // MARK: - Charging

    private var chargingSection: some View {
        DetailSection(title: String(localized: "Charging Details"), icon: "battery.100.bolt", color: .blue) {
            DetailRow(label: String(localized: "Currently Charging"), value: data.isCharging ? String(localized: "Yes") : String(localized: "No"))
            DetailRow(label: String(localized: "Fully Charged"), value: data.fullyCharged ? String(localized: "Yes") : String(localized: "No"))
            if let cv = data.chargingVoltageMV {
                DetailRow(label: String(localized: "Cell Charging Voltage"), value: String(format: "%.3f V", Double(cv) / 1000.0))
            }
            if let cc = data.chargingCurrentMA {
                DetailRow(label: String(localized: "Charging Current"), value: String(format: "%d mA", cc))
            }
            if let vac = data.vacVoltageLimit {
                DetailRow(label: String(localized: "Max Charging Voltage Limit"), value: String(format: "%.3f V", Double(vac) / 1000.0))
            }
            if let reason = data.notChargingReasonDescription {
                DetailRow(label: String(localized: "Not Charging Reason"), value: reason)
            } else if !data.isCharging, data.effectiveIsOnAC {
                DetailRow(label: String(localized: "Not Charging Reason"), value: String(localized: "None"))
            }
        }
    }

    // MARK: - Lifetime

    private var lifetimeSection: some View {
        DetailSection(title: String(localized: "Lifetime Statistics"), icon: "clock.arrow.circlepath", color: .purple) {
            if let total = data.totalOperatingTimeMin {
                let hours = total / 60
                DetailRow(label: String(localized: "Total Operating Time"), value: "\(hours) \(String(localized: "hours")) (\(total) \(String(localized: "minutes")))")
            }
            if let maxT = data.lifetimeMaxTempC {
                let c = TemperatureUnits.lifetimeCelsius(fromWholeDegrees: maxT)
                DetailRow(label: String(localized: "Battery Max Temperature"), value: "\(c) °C")
            }
            if let minT = data.lifetimeMinTempC {
                let c = TemperatureUnits.lifetimeCelsius(fromWholeDegrees: minT)
                DetailRow(label: String(localized: "Battery Min Temperature"), value: "\(c) °C")
            }
            if let avgT = data.lifetimeAvgTempC {
                DetailRow(
                    label: String(localized: "Battery Avg Temperature"),
                    value: String(format: "%.1f °C", TemperatureUnits.lifetimeAvgCelsius(fromDecidegrees: avgT))
                )
            }
            if let maxV = data.lifetimeMaxPackVoltageMV {
                DetailRow(label: String(localized: "Max Pack Voltage"), value: String(format: "%.3f V", Double(maxV) / 1000.0))
            }
            if let minV = data.lifetimeMinPackVoltageMV {
                DetailRow(label: String(localized: "Min Pack Voltage"), value: String(format: "%.3f V", Double(minV) / 1000.0))
            }
            if let maxCharge = data.lifetimeMaxChargeCurrentMA, maxCharge < 100_000 {
                DetailRow(label: String(localized: "Max Charging Current"), value: "\(maxCharge) mA")
            }
            if let maxDischarge = data.lifetimeMaxDischargeCurrentMA, maxDischarge < 100_000 {
                DetailRow(label: String(localized: "Max Discharging Current"), value: "\(maxDischarge) mA")
            }
            if let discCount = data.batteryCellDisconnectCount {
                DetailRow(label: String(localized: "Cell Safety Trigger Count"), value: "\(discCount)")
            }
        }
    }

    // MARK: - Device Info

    private var deviceInfoSection: some View {
        DetailSection(title: String(localized: "Device Information"), icon: "info.circle", color: .secondary) {
            if let serial = data.batterySerial {
                DetailRow(label: String(localized: "Battery Serial Number"), value: serial)
            }
            if let name = data.deviceName {
                DetailRow(label: String(localized: "Battery Gauge Chip"), value: name)
            }
        }
    }
}

// MARK: - Helper Views

private struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.system(size: 12))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .padding(.bottom, 2)

            content
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var bar: (value: Double, total: Double)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(minWidth: 160, alignment: .leading)

            if let bar {
                ProgressView(value: bar.value, total: bar.total)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 80)
            }

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: highlight ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? .primary : .secondary)
        }
    }
}

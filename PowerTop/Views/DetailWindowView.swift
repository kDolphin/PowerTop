import SwiftUI

struct DetailWindowView: View {
    let monitor: PowerMonitor

    private var data: PowerData { monitor.currentData }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if monitor.isDataAvailable {
                    currentPowerSection
                    batteryHealthSection
                    if hasCellData { cellDataSection }
                    if hasLifetimeData { lifetimeSection }
                    if hasDeviceInfo { deviceInfoSection }
                    footerTimestamp
                } else {
                    unavailableState
                }
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 500)
        .background(.windowBackground)
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    // MARK: - Current Power (merged power + contextual charging)

    private var currentPowerSection: some View {
        DetailSection(title: String(localized: "Current Power"), icon: "bolt.fill", color: .green) {
            DetailRow(label: String(localized: "Power Source"), value: data.powerSourceDescription)
            DetailRow(
                label: String(localized: "System Power"),
                value: String(format: "%.1f W", data.systemPowerW),
                highlight: true
            )

            if data.effectiveIsOnAC && !data.isConnectingAC {
                DetailRow(
                    label: String(localized: "AC Adapter Output"),
                    value: String(format: "%.1f W", data.effectiveACOutputW)
                )
            }

            if data.isBatteryCharging {
                DetailRow(
                    label: String(localized: "Battery Charging"),
                    value: String(format: "%.1f W", data.batteryChargeRateW)
                )
            } else if data.isSupplementalDischarge {
                DetailRow(
                    label: String(localized: "Battery Supplement"),
                    value: String(format: "%.1f W", data.batterySupplementalW)
                )
            } else if !data.effectiveIsOnAC, data.batteryPowerW > 0.3 {
                DetailRow(
                    label: String(localized: "Battery Discharging Power"),
                    value: String(format: "%.1f W", data.batteryPowerW)
                )
            } else if data.effectiveIsOnAC, data.batteryPowerW < -0.3 {
                DetailRow(
                    label: String(localized: "Battery Charging Power"),
                    value: String(format: "%.1f W", abs(data.batteryPowerW))
                )
            }

            if data.effectiveIsOnAC && !data.isConnectingAC && data.acAdapterWattage > 0 {
                DetailRow(
                    label: String(localized: "Charger Spec"),
                    value: "\(data.acAdapterWattage) W" + (data.adapterDescription.map { " (\($0))" } ?? "")
                )
                let usage = data.effectiveACOutputW / Double(data.acAdapterWattage) * 100
                DetailRow(
                    label: String(localized: "Charger Load Rate"),
                    value: String(format: "%.0f%%", usage),
                    bar: (min(usage, 100), 100)
                )
            }

            if let timeText = data.estimatedTimeRemainingText {
                DetailRow(label: data.estimatedTimeRemainingLabel, value: timeText)
            }

            if data.effectiveIsOnAC && !data.isConnectingAC {
                DetailSubheading(String(localized: "Charging Status"))
                DetailRow(
                    label: String(localized: "Charging Status"),
                    value: data.isBatteryCharging ? String(localized: "Charging") : String(localized: "Not Charging")
                )
                if data.fullyCharged {
                    DetailRow(label: String(localized: "Fully Charged"), value: String(localized: "Yes"))
                }
                if let reason = data.notChargingReasonDescription {
                    DetailRow(label: String(localized: "Not Charging Reason"), value: reason)
                }
                if let cv = data.chargingVoltageMV {
                    DetailRow(
                        label: String(localized: "Cell Charging Voltage"),
                        value: String(format: "%.3f V", Double(cv) / 1000.0)
                    )
                }
                if let cc = data.chargingCurrentMA {
                    DetailRow(label: String(localized: "Charging Current"), value: String(format: "%d mA", cc))
                }
                if let vac = data.vacVoltageLimit {
                    DetailRow(
                        label: String(localized: "Max Charging Voltage Limit"),
                        value: String(format: "%.3f V", Double(vac) / 1000.0)
                    )
                }
            }

            if data.wallPowerW != nil || data.adapterEfficiencyLossW != nil || data.averageSystemPowerW != nil {
                DetailSubheading(String(localized: "Historical Averages"))
                if let avg = data.averageSystemPowerW, avg > 0.5 {
                    DetailRow(
                        label: String(localized: "Average System Power"),
                        value: String(format: "%.1f W", avg)
                    )
                }
                if let wall = data.wallPowerW {
                    DetailRow(
                        label: String(localized: "Avg Wall Outlet Power"),
                        value: String(format: "%.1f W", wall)
                    )
                }
                if let loss = data.adapterEfficiencyLossW {
                    DetailRow(
                        label: String(localized: "Avg Adapter Loss"),
                        value: String(format: "%.1f W", loss)
                    )
                }
            }

            if data.effectiveIsOnAC && !data.isConnectingAC {
                if let sv = data.systemVoltageMV {
                    DetailRow(
                        label: String(localized: "Charger Output Voltage"),
                        value: String(format: "%.2f V", Double(sv) / 1000.0)
                    )
                }
                if let sc = data.systemCurrentMA {
                    DetailRow(
                        label: String(localized: "Charger Output Current"),
                        value: String(format: "%.3f A", Double(sc) / 1000.0)
                    )
                }
            }

            if data.dataSource == .legacy {
                DetailRow(
                    label: String(localized: "Data Source"),
                    value: String(localized: "Estimation Mode — telemetry unavailable")
                )
            }
        }
    }

    // MARK: - Battery Health

    private var batteryHealthSection: some View {
        DetailSection(title: String(localized: "Battery Health"), icon: "heart.fill", color: healthColor) {
            if let health = data.batteryHealthPercent {
                DetailRow(
                    label: String(localized: "Health"),
                    value: "\(health)%",
                    highlight: true,
                    bar: (Double(health), 100)
                )
            }
            if let soc = data.stateOfCharge {
                DetailRow(label: String(localized: "Battery Level"), value: "\(soc)%")
            } else {
                DetailRow(label: String(localized: "Battery Level"), value: "\(data.batteryPercent)%")
            }
            if let cycles = data.cycleCount, let designCycles = data.designCycleCount {
                DetailRow(
                    label: String(localized: "Cycle Count"),
                    value: "\(cycles) / \(designCycles) (\(String(localized: "design life")))",
                    bar: (Double(cycles), Double(designCycles))
                )
            } else if let cycles = data.cycleCount {
                DetailRow(label: String(localized: "Cycle Count"), value: "\(cycles)")
            }
            if let temp = data.batteryTemperatureC {
                DetailRow(
                    label: String(localized: "Battery Temp"),
                    value: String(format: "%.1f °C", temp)
                )
            }
            if let mfg = data.batteryManufactureDate {
                DetailRow(label: String(localized: "Manufacture Date"), value: mfg)
            }
            if let minSoc = data.dailyMinSoc, let maxSoc = data.dailyMaxSoc {
                DetailRow(
                    label: String(localized: "Optimized Charging Range"),
                    value: "\(minSoc)% - \(maxSoc)%"
                )
            }

            if hasCapacityDetails {
                DetailSubheading(String(localized: "Capacity Details"))
                if let remaining = data.remainingCapacityMAH {
                    DetailRow(label: String(localized: "Remaining Capacity"), value: "\(remaining) mAh")
                }
                if let design = data.designCapacityMAH {
                    DetailRow(label: String(localized: "Design Capacity"), value: "\(design) mAh")
                }
                if let raw = data.rawMaxCapacityMAH {
                    DetailRow(label: String(localized: "Full Charge Capacity"), value: "\(raw) mAh")
                }
                if let nom = data.nominalChargeCapacityMAH {
                    DetailRow(label: String(localized: "Nominal Full Charge Capacity"), value: "\(nom) mAh")
                }
            }

            if hasElectricalReadings {
                DetailSubheading(String(localized: "Electrical Readings"))
                if let voltage = data.batteryVoltageMV {
                    DetailRow(
                        label: String(localized: "Battery Voltage"),
                        value: String(format: "%.2f V", Double(voltage) / 1000.0)
                    )
                }
                if let amp = data.batteryAmperageMA {
                    let sign = amp > 0
                        ? String(localized: "Discharging")
                        : (amp < 0 ? String(localized: "Charging") : String(localized: "Idle"))
                    DetailRow(
                        label: String(localized: "Battery Current"),
                        value: String(format: "%d mA (%@)", abs(amp), sign)
                    )
                }
                if let instant = data.instantAmperageMA {
                    DetailRow(
                        label: String(localized: "Battery Instant Current"),
                        value: String(format: "%d mA", instant)
                    )
                }
            }

            if hasStatusAlerts {
                DetailSubheading(String(localized: "Status & Alerts"))
                if let critical = data.atCriticalLevel {
                    DetailRow(
                        label: String(localized: "Critical Low Battery"),
                        value: critical ? String(localized: "Yes") : String(localized: "No")
                    )
                }
                if let failure = data.permanentFailureStatus {
                    DetailRow(
                        label: String(localized: "Permanent Failure Status"),
                        value: failure == 0
                            ? String(localized: "Normal")
                            : String(format: String(localized: "Abnormal (%d)"), failure)
                    )
                }
            }
        }
    }

    // MARK: - Additional sections

    private var cellDataSection: some View {
        DetailSection(title: String(localized: "Cell Data"), icon: "cylinder.split.1.raised", color: .cyan) {
            if let cells = data.cellVoltagesMV {
                if let balance = cellBalanceSummary(cells) {
                    DetailRow(label: String(localized: "Cell Balance"), value: balance)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { idx, mv in
                    DetailRow(
                        label: String(format: String(localized: "Cell %d Voltage"), idx + 1),
                        value: String(format: "%.3f V", Double(mv) / 1000.0)
                    )
                }
            }
            if let qmax = data.qmaxMAH {
                ForEach(Array(qmax.enumerated()), id: \.offset) { idx, mah in
                    DetailRow(
                        label: String(format: String(localized: "Cell %d Full Charge Capacity"), idx + 1),
                        value: "\(mah) mAh"
                    )
                }
            }
        }
    }

    private var lifetimeSection: some View {
        DetailSection(title: String(localized: "Lifetime Statistics"), icon: "clock.arrow.circlepath", color: .purple) {
            DetailSubheading(String(localized: "Since First Use"))
            if let total = data.totalOperatingTimeMin {
                let hours = total / 60
                DetailRow(
                    label: String(localized: "Total Operating Time"),
                    value: "\(hours) \(String(localized: "hours"))"
                )
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
                DetailRow(
                    label: String(localized: "Max Pack Voltage"),
                    value: String(format: "%.3f V", Double(maxV) / 1000.0)
                )
            }
            if let minV = data.lifetimeMinPackVoltageMV {
                DetailRow(
                    label: String(localized: "Min Pack Voltage"),
                    value: String(format: "%.3f V", Double(minV) / 1000.0)
                )
            }
            if let maxCharge = data.lifetimeMaxChargeCurrentMA, maxCharge < 100_000 {
                DetailRow(label: String(localized: "Max Charging Current"), value: "\(maxCharge) mA")
            }
            if let maxDischarge = data.lifetimeMaxDischargeCurrentMA, maxDischarge < 100_000 {
                DetailRow(label: String(localized: "Max Discharging Current"), value: "\(maxDischarge) mA")
            }
            if let discCount = data.batteryCellDisconnectCount {
                DetailRow(
                    label: String(localized: "Protection Trigger Count"),
                    value: protectionTriggerLabel(count: discCount)
                )
            }
        }
    }

    private var deviceInfoSection: some View {
        DetailSection(title: String(localized: "Device Information"), icon: "info.circle", color: .secondary) {
            if let serial = data.batterySerial {
                DetailRow(label: String(localized: "Battery Serial Number"), value: serial)
            }
            if let name = data.deviceName {
                DetailRow(label: String(localized: "Battery Management Chip"), value: name)
            }
            Text(String(localized: "Device info is shown locally only and is not uploaded."))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    private var footerTimestamp: some View {
        HStack {
            Spacer()
            Text(
                String(
                    format: String(localized: "Updated at %@"),
                    data.timestamp.formatted(date: .omitted, time: .standard)
                )
            )
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(String(localized: "Built-in battery not detected. PowerTop requires a MacBook."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private var hasCellData: Bool {
        data.cellVoltagesMV != nil || data.qmaxMAH != nil
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

    private var hasCapacityDetails: Bool {
        data.remainingCapacityMAH != nil
            || data.designCapacityMAH != nil
            || data.rawMaxCapacityMAH != nil
            || data.nominalChargeCapacityMAH != nil
    }

    private var hasElectricalReadings: Bool {
        data.batteryVoltageMV != nil
            || data.batteryAmperageMA != nil
            || data.instantAmperageMA != nil
    }

    private var hasStatusAlerts: Bool {
        data.atCriticalLevel != nil || data.permanentFailureStatus != nil
    }

    private var healthColor: Color {
        guard let h = data.batteryHealthPercent else { return .secondary }
        if h >= 80 { return .green }
        if h >= 60 { return .orange }
        return .red
    }

    private func cellBalanceSummary(_ cells: [Int]) -> String? {
        guard cells.count >= 2, let minMV = cells.min(), let maxMV = cells.max() else { return nil }
        let delta = maxMV - minMV
        let status: String
        if delta <= 50 {
            status = String(localized: "Normal")
        } else if delta <= 100 {
            status = String(localized: "Fair")
        } else {
            status = String(localized: "Worth Checking")
        }
        return String(format: String(localized: "%d mV spread — %@"), delta, status)
    }

    private func protectionTriggerLabel(count: Int) -> String {
        if count == 0 {
            return String(localized: "0 (normal)")
        }
        return "\(count)"
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

private struct DetailSubheading: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var bar: (value: Double, total: Double)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(minWidth: 140, maxWidth: 200, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let bar {
                ProgressView(value: bar.value, total: bar.total)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 72)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: highlight ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? .primary : .secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
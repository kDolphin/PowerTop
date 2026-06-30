import SwiftUI

struct DetailWindowView: View {
    static let preferredWidth: CGFloat = 460

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
        .frame(width: Self.preferredWidth)
        .frame(minHeight: 500)
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
                if let footnote = data.estimatedTimeFootnote {
                    Text(footnote)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
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
            DetailSubheading(String(localized: "At a Glance"))
            OverviewMetricRow(
                label: String(localized: "Battery Level"),
                value: "\(batteryLevelPercent)%",
                barValue: Double(batteryLevelPercent),
                barTotal: 100,
                barTint: batteryLevelBarTint
            )
            OverviewMetricRow(
                label: String(localized: "Health"),
                value: data.batteryHealthPercent.map { "\($0)%" } ?? unavailableValue,
                highlight: data.batteryHealthPercent != nil,
                barValue: data.batteryHealthPercent.map(Double.init),
                barTotal: 100,
                barTint: healthColor
            )
            OverviewMetricRow(
                label: String(localized: "Cycle Count"),
                value: cycleCountText,
                barValue: cycleCountBar?.0,
                barTotal: cycleCountBar?.1 ?? 100,
                barTint: .secondary
            )

            DetailSubheading(String(localized: "Capacity"))
            DetailRow(
                label: String(localized: "Design Capacity"),
                value: formatCapacityMAH(data.designCapacityMAH)
            )
            DetailRow(
                label: String(localized: "Current Full Charge"),
                value: formatCapacityMAH(data.fullChargeCapacityMAH ?? data.rawMaxCapacityMAH)
            )
            DetailRow(
                label: String(localized: "Calibrated Full Charge"),
                value: formatCapacityMAH(data.nominalChargeCapacityMAH)
            )
            DetailRow(
                label: String(localized: "Remaining Charge"),
                value: formatCapacityMAH(data.remainingCapacityMAH)
            )

            if hasChargingCareDetails {
                DetailSubheading(String(localized: "Charging & Care"))
                if data.chargeLimitPercent < 100 {
                    DetailRow(
                        label: String(localized: "Charge Limit"),
                        value: chargeLimitText
                    )
                }
                if let minSoc = data.dailyMinSoc, let maxSoc = data.dailyMaxSoc {
                    DetailRow(
                        label: String(localized: "Optimized Charging Range"),
                        value: "\(minSoc)% – \(maxSoc)%"
                    )
                }
                if let temp = data.batteryTemperatureC {
                    DetailRow(
                        label: String(localized: "Battery Temp"),
                        value: String(format: "%.1f °C", temp)
                    )
                }
            }

            if hasElectricalReadings {
                DetailSubheading(String(localized: "Live Readings"))
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
            if let topology = cellTopologyDescription {
                Text(topology)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 2)
            }

            if let cells = data.cellVoltagesMV, let balance = seriesVoltageBalanceSummary(cells) {
                DetailRow(label: String(localized: "Series Voltage Balance"), value: balance)
            }
            if usesSeriesParallelLayout,
               let currents = data.batteryParallelCellCurrents,
               let balance = parallelCurrentBalanceSummary(currents) {
                DetailRow(label: String(localized: "Parallel Current Balance"), value: balance)
            }

            if usesSeriesParallelLayout {
                DetailSubheading(String(localized: "Series Groups"))
                Text(String(localized: "Series group Qmax is the parallel pair's estimated full-charge capacity (mAh), not derived from cell currents."))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 2)
                ForEach(Array(seriesGroupEntries.enumerated()), id: \.offset) { idx, entry in
                    DetailRow(
                        label: String(format: String(localized: "Series Group %d"), idx + 1),
                        value: seriesGroupSummary(voltageMV: entry.voltageMV, qmaxMAH: entry.qmaxMAH)
                    )
                }
                if let currents = data.batteryParallelCellCurrents, !currents.isEmpty {
                    DetailSubheading(String(localized: "Parallel Cell Currents"))
                    Text(String(localized: "Instantaneous current per parallel cell; unequal split within a group is normal."))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 2)
                    ForEach(Array(currents.enumerated()), id: \.offset) { _, cell in
                        DetailRow(
                            label: parallelCellLabel(bankID: cell.bankID, cellID: cell.cellID),
                            value: "\(cell.currentMA) mA"
                        )
                    }
                }
            } else {
                ForEach(Array(cellDisplayEntries.enumerated()), id: \.offset) { idx, entry in
                    DetailRow(
                        label: String(format: String(localized: "Cell %d"), idx + 1),
                        value: cellSummary(voltageMV: entry.voltageMV, qmaxMAH: entry.qmaxMAH)
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
            if let mfg = data.batteryManufactureDate {
                DetailRow(label: String(localized: "Manufacture Date"), value: mfg)
            }
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
        !cellDisplayEntries.isEmpty
            || !(data.batteryParallelCellCurrents?.isEmpty ?? true)
    }

    private var usesSeriesParallelLayout: Bool {
        if case .seriesParallel = data.batteryCellLayout { return true }
        return false
    }

    private var cellTopologyDescription: String? {
        switch data.batteryCellLayout {
        case .seriesParallel(let seriesCount, let parallelCount, let parallelCountKnown):
            if parallelCountKnown, parallelCount > 1 {
                return String(
                    format: String(localized: "Battery topology: %dS%dP (%d cells)"),
                    seriesCount,
                    parallelCount,
                    seriesCount * parallelCount
                )
            }
            return String(
                format: String(localized: "Battery topology: %d series groups"),
                seriesCount
            )
        case .perCellArrays:
            if let count = data.cellVoltagesMV?.count, count > 0 {
                return String(format: String(localized: "Battery topology: %d cells"), count)
            }
            return nil
        case nil:
            return nil
        }
    }

    private var seriesGroupEntries: [(voltageMV: Int?, qmaxMAH: Int?)] {
        cellDisplayEntries
    }

    private var cellDisplayEntries: [(voltageMV: Int?, qmaxMAH: Int?)] {
        let voltages = data.cellVoltagesMV ?? []
        let capacities = data.qmaxMAH ?? []
        let count = max(voltages.count, capacities.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            (
                voltageMV: index < voltages.count ? voltages[index] : nil,
                qmaxMAH: index < capacities.count ? capacities[index] : nil
            )
        }
    }

    private func parallelCellLabel(bankID: Int, cellID: Int) -> String {
        String(
            format: String(localized: "Series Group %d · Cell %d"),
            bankID + 1,
            cellID + 1
        )
    }

    private func seriesGroupSummary(voltageMV: Int?, qmaxMAH: Int?) -> String {
        var parts: [String] = []
        if let voltageMV {
            parts.append(String(format: "%.3f V", Double(voltageMV) / 1000.0))
        }
        if let qmaxMAH {
            parts.append(String(format: String(localized: "Qmax %d mAh"), qmaxMAH))
        }
        return parts.isEmpty ? String(localized: "—") : parts.joined(separator: " · ")
    }

    private func cellSummary(voltageMV: Int?, qmaxMAH: Int?) -> String {
        var parts: [String] = []
        if let voltageMV {
            parts.append(String(format: "%.3f V", Double(voltageMV) / 1000.0))
        }
        if let qmaxMAH {
            parts.append("\(qmaxMAH) mAh")
        }
        return parts.isEmpty ? String(localized: "—") : parts.joined(separator: " · ")
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
        data.batterySerial != nil || data.deviceName != nil || data.batteryManufactureDate != nil
    }

    private var unavailableValue: String {
        String(localized: "—")
    }

    private var hasChargingCareDetails: Bool {
        data.chargeLimitPercent < 100
            || (data.dailyMinSoc != nil && data.dailyMaxSoc != nil)
            || data.batteryTemperatureC != nil
    }

    private var chargeLimitText: String {
        if let source = chargeLimitSourceLabel(data.chargeLimitSource) {
            return "\(data.chargeLimitPercent)% (\(source))"
        }
        return "\(data.chargeLimitPercent)%"
    }

    private var cycleCountText: String {
        guard let cycles = data.cycleCount else { return unavailableValue }
        if let designCycles = data.designCycleCount {
            return "\(cycles) / \(designCycles) (\(String(localized: "design life")))"
        }
        return "\(cycles)"
    }

    private var batteryLevelPercent: Int {
        data.stateOfCharge ?? data.batteryPercent
    }

    private var batteryLevelBarTint: Color {
        let level = batteryLevelPercent
        if level <= 20 { return .red }
        if level <= 50 { return .orange }
        return .green
    }

    private var cycleCountBar: (Double, Double)? {
        guard let cycles = data.cycleCount, let designCycles = data.designCycleCount, designCycles > 0 else {
            return nil
        }
        return (Double(cycles), Double(designCycles))
    }

    private func formatCapacityMAH(_ value: Int?) -> String {
        value.map { "\($0) mAh" } ?? unavailableValue
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

    private func seriesVoltageBalanceSummary(_ voltagesMV: [Int]) -> String? {
        guard voltagesMV.count >= 2, let minMV = voltagesMV.min(), let maxMV = voltagesMV.max() else { return nil }
        let delta = maxMV - minMV
        return String(format: String(localized: "%d mV spread — %@"), delta, balanceStatus(forMillivoltSpread: delta))
    }

    private func parallelCurrentBalanceSummary(_ currents: [BatteryParallelCellCurrent]) -> String? {
        let grouped = Dictionary(grouping: currents, by: \.bankID)
        let spreads = grouped.values.compactMap { cells -> Int? in
            guard cells.count >= 2 else { return nil }
            let values = cells.map(\.currentMA)
            guard let minMA = values.min(), let maxMA = values.max() else { return nil }
            return maxMA - minMA
        }
        guard let worstSpread = spreads.max() else { return nil }
        return String(
            format: String(localized: "%d mA max within-group spread — %@"),
            worstSpread,
            balanceStatus(forMilliampSpread: worstSpread)
        )
    }

    private func balanceStatus(forMillivoltSpread delta: Int) -> String {
        if delta <= 50 { return String(localized: "Normal") }
        if delta <= 100 { return String(localized: "Fair") }
        return String(localized: "Worth Checking")
    }

    private func balanceStatus(forMilliampSpread delta: Int) -> String {
        if delta <= 80 { return String(localized: "Normal") }
        if delta <= 150 { return String(localized: "Fair") }
        return String(localized: "Worth Checking")
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

/// Overview rows share a fixed label + bar column; values align to the trailing edge.
private struct OverviewMetricRow: View {
    static let labelWidth: CGFloat = 96
    static let barWidth: CGFloat = 80

    let label: String
    let value: String
    var highlight: Bool = false
    var barValue: Double?
    var barTotal: Double = 100
    var barTint: Color = .accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: Self.labelWidth, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            ProgressView(value: progressValue, total: max(barTotal, 1))
                .progressViewStyle(.linear)
                .tint(barTint)
                .frame(width: Self.barWidth)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: highlight ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? .primary : .secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressValue: Double {
        guard let barValue, barTotal > 0 else { return 0 }
        return min(max(barValue, 0), barTotal)
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
                .frame(minWidth: 128, maxWidth: 168, alignment: .leading)
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
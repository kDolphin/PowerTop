import Foundation

enum PowerDataSource {
    case telemetry
    case legacy
}

/// How macOS exposes per-cell battery telemetry on this machine.
enum BatteryCellTelemetryLayout: Equatable {
    /// Pack-level `CellVoltage` / `Qmax` arrays — one entry per physical cell.
    case perCellArrays
    /// Bank/cell nodes — voltage and Qmax per series group, currents per parallel cell.
    /// `parallelCountKnown` is false when no cell nodes were found (topology shows series groups only).
    case seriesParallel(seriesCount: Int, parallelCount: Int, parallelCountKnown: Bool)
}

struct BatteryParallelCellCurrent: Equatable {
    let bankID: Int
    let cellID: Int
    let currentMA: Int
}

struct PowerData {
    // Core power metrics
    let systemPowerW: Double          // SystemLoad / 1000 — actual system consumption
    let batteryPowerW: Double         // BatteryPower / 1000 — positive=discharge, negative=charge
    let acInputW: Double              // SystemPowerIn / 1000 — total DC from charger
    let acAdapterWattage: Int
    let batteryPercent: Int
    let isOnAC: Bool
    let isCharging: Bool
    let fullyCharged: Bool
    let wallPowerW: Double?
    let adapterEfficiencyLossW: Double?
    let systemVoltageMV: Int?
    let systemCurrentMA: Int?
    let batteryVoltageMV: Int?
    let batteryAmperageMA: Int?
    let batteryTemperatureC: Double?
    let cycleCount: Int?
    let adapterDescription: String?
    let dataSource: PowerDataSource
    let timestamp: Date
    let connectionPhase: PowerConnectionPhase

    // Battery health
    let batteryHealthPercent: Int?
    let designCapacityMAH: Int?
    let rawMaxCapacityMAH: Int?
    let nominalChargeCapacityMAH: Int?
    let designCycleCount: Int?

    // Charging details
    let chargingVoltageMV: Int?
    let chargingCurrentMA: Int?
    let notChargingReason: Int?
    let vacVoltageLimit: Int?

    // Cell-level data
    let cellVoltagesMV: [Int]?
    let stateOfCharge: Int?
    let qmaxMAH: [Int]?
    let batteryCellLayout: BatteryCellTelemetryLayout?
    let batteryParallelCellCurrents: [BatteryParallelCellCurrent]?
    let dailyMinSoc: Int?
    let dailyMaxSoc: Int?

    // Lifetime statistics
    let totalOperatingTimeMin: Int?
    let lifetimeMaxTempC: Int?
    let lifetimeMinTempC: Int?
    let lifetimeAvgTempC: Int?
    let lifetimeMaxPackVoltageMV: Int?
    let lifetimeMinPackVoltageMV: Int?
    let lifetimeMaxChargeCurrentMA: Int?
    let lifetimeMaxDischargeCurrentMA: Int?

    // Device info
    let batterySerial: String?
    let deviceName: String?
    let instantAmperageMA: Int?
    let atCriticalLevel: Bool?
    let permanentFailureStatus: Int?
    let batteryCellDisconnectCount: Int?

    // Battery timing and capacity (from IOKit; display via computed helpers below)
    let avgTimeToEmptyMinutes: Int?
    let avgTimeToFullMinutes: Int?
    let remainingCapacityMAH: Int?
    let fullChargeCapacityMAH: Int?
    let averageSystemPowerW: Double?
    let batteryManufactureDate: String?
    /// EMA-smoothed discharge/charge power for time estimates (set by PowerMonitor).
    let smoothedDischargePowerW: Double?
    let smoothedChargePowerW: Double?

    // Full memberwise init (package-internal; centralizes all assignments to avoid drift across call sites)
    init(
        systemPowerW: Double, batteryPowerW: Double, acInputW: Double,
        acAdapterWattage: Int, batteryPercent: Int,
        isOnAC: Bool, isCharging: Bool, fullyCharged: Bool,
        wallPowerW: Double?, adapterEfficiencyLossW: Double?,
        systemVoltageMV: Int?, systemCurrentMA: Int?,
        batteryVoltageMV: Int?, batteryAmperageMA: Int?,
        batteryTemperatureC: Double?, cycleCount: Int?,
        adapterDescription: String?, dataSource: PowerDataSource, timestamp: Date,
        connectionPhase: PowerConnectionPhase,
        batteryHealthPercent: Int?, designCapacityMAH: Int?, rawMaxCapacityMAH: Int?,
        nominalChargeCapacityMAH: Int?, designCycleCount: Int?,
        chargingVoltageMV: Int?, chargingCurrentMA: Int?, notChargingReason: Int?, vacVoltageLimit: Int?,
        cellVoltagesMV: [Int]?, stateOfCharge: Int?, qmaxMAH: [Int]?,
        batteryCellLayout: BatteryCellTelemetryLayout?, batteryParallelCellCurrents: [BatteryParallelCellCurrent]?,
        dailyMinSoc: Int?, dailyMaxSoc: Int?,
        totalOperatingTimeMin: Int?,
        lifetimeMaxTempC: Int?, lifetimeMinTempC: Int?, lifetimeAvgTempC: Int?,
        lifetimeMaxPackVoltageMV: Int?, lifetimeMinPackVoltageMV: Int?,
        lifetimeMaxChargeCurrentMA: Int?, lifetimeMaxDischargeCurrentMA: Int?,
        batterySerial: String?, deviceName: String?,
        instantAmperageMA: Int?, atCriticalLevel: Bool?,
        permanentFailureStatus: Int?, batteryCellDisconnectCount: Int?,
        avgTimeToEmptyMinutes: Int?, avgTimeToFullMinutes: Int?,
        remainingCapacityMAH: Int?, fullChargeCapacityMAH: Int?,
        averageSystemPowerW: Double?, batteryManufactureDate: String?,
        smoothedDischargePowerW: Double?, smoothedChargePowerW: Double?
    ) {
        self.systemPowerW = systemPowerW
        self.batteryPowerW = batteryPowerW
        self.acInputW = acInputW
        self.acAdapterWattage = acAdapterWattage
        self.batteryPercent = batteryPercent
        self.isOnAC = isOnAC
        self.isCharging = isCharging
        self.fullyCharged = fullyCharged
        self.wallPowerW = wallPowerW
        self.adapterEfficiencyLossW = adapterEfficiencyLossW
        self.systemVoltageMV = systemVoltageMV
        self.systemCurrentMA = systemCurrentMA
        self.batteryVoltageMV = batteryVoltageMV
        self.batteryAmperageMA = batteryAmperageMA
        self.batteryTemperatureC = batteryTemperatureC
        self.cycleCount = cycleCount
        self.adapterDescription = adapterDescription
        self.dataSource = dataSource
        self.timestamp = timestamp
        self.connectionPhase = connectionPhase
        self.batteryHealthPercent = batteryHealthPercent
        self.designCapacityMAH = designCapacityMAH
        self.rawMaxCapacityMAH = rawMaxCapacityMAH
        self.nominalChargeCapacityMAH = nominalChargeCapacityMAH
        self.designCycleCount = designCycleCount
        self.chargingVoltageMV = chargingVoltageMV
        self.chargingCurrentMA = chargingCurrentMA
        self.notChargingReason = notChargingReason
        self.vacVoltageLimit = vacVoltageLimit
        self.cellVoltagesMV = cellVoltagesMV
        self.stateOfCharge = stateOfCharge
        self.qmaxMAH = qmaxMAH
        self.batteryCellLayout = batteryCellLayout
        self.batteryParallelCellCurrents = batteryParallelCellCurrents
        self.dailyMinSoc = dailyMinSoc
        self.dailyMaxSoc = dailyMaxSoc
        self.totalOperatingTimeMin = totalOperatingTimeMin
        self.lifetimeMaxTempC = lifetimeMaxTempC
        self.lifetimeMinTempC = lifetimeMinTempC
        self.lifetimeAvgTempC = lifetimeAvgTempC
        self.lifetimeMaxPackVoltageMV = lifetimeMaxPackVoltageMV
        self.lifetimeMinPackVoltageMV = lifetimeMinPackVoltageMV
        self.lifetimeMaxChargeCurrentMA = lifetimeMaxChargeCurrentMA
        self.lifetimeMaxDischargeCurrentMA = lifetimeMaxDischargeCurrentMA
        self.batterySerial = batterySerial
        self.deviceName = deviceName
        self.instantAmperageMA = instantAmperageMA
        self.atCriticalLevel = atCriticalLevel
        self.permanentFailureStatus = permanentFailureStatus
        self.batteryCellDisconnectCount = batteryCellDisconnectCount
        self.avgTimeToEmptyMinutes = avgTimeToEmptyMinutes
        self.avgTimeToFullMinutes = avgTimeToFullMinutes
        self.remainingCapacityMAH = remainingCapacityMAH
        self.fullChargeCapacityMAH = fullChargeCapacityMAH
        self.averageSystemPowerW = averageSystemPowerW
        self.batteryManufactureDate = batteryManufactureDate
        self.smoothedDischargePowerW = smoothedDischargePowerW
        self.smoothedChargePowerW = smoothedChargePowerW
    }

    // MARK: - Computed properties

    var isConnectingAC: Bool {
        connectionPhase == .connectingAC
    }

    /// State machine or ExternalConnected=false — stale telemetry is ignored.
    private var clearlyOnBattery: Bool {
        connectionPhase == .onBattery || !isOnAC
    }

    /// AC input used for state logic — zero when unplugged or still connecting.
    var effectiveACInputW: Double {
        if clearlyOnBattery || isConnectingAC { return 0 }
        return isOnAC ? acInputW : 0
    }

    /// Effective AC status — driven by connection phase, then telemetry.
    var effectiveIsOnAC: Bool {
        if clearlyOnBattery { return false }
        if isConnectingAC { return true }
        if effectiveACInputW > 0 { return true }
        if isCharging { return true }
        return connectionPhase == .onAC
    }

    /// Effective AC output in watts.
    /// Uses SystemPowerIn when available; estimates when SystemPowerIn is 0 or outdated.
    var effectiveACOutputW: Double {
        if !effectiveIsOnAC || isConnectingAC { return 0 }
        if effectiveACInputW > 0 { return effectiveACInputW }
        if isBatteryCharging {
            return systemPowerW + batteryChargeRateW
        }
        return systemPowerW
    }

    private var isBatteryDischarging: Bool {
        batteryPowerW > 0.3
    }

    /// Whether the battery is actively charging.
    /// AC input exceeding system load means surplus is charging the battery.
    var isBatteryCharging: Bool {
        if clearlyOnBattery || isConnectingAC { return false }
        if isBatteryDischarging { return false }
        if batteryPowerW < -0.3 { return true }

        let hasSurplusAC = effectiveACInputW > systemPowerW + 0.5
        if hasSurplusAC {
            if fullyCharged { return false }
            if let reason = notChargingReason, reason != 0 { return false }
            return true
        }

        if isCharging { return true }
        return false
    }

    /// Battery charge rate in watts (positive value).
    var batteryChargeRateW: Double {
        if !isBatteryCharging { return 0 }
        if batteryPowerW < 0 { return abs(batteryPowerW) }
        if effectiveACInputW > systemPowerW { return effectiveACInputW - systemPowerW }
        return 0
    }

    /// How much power the AC adapter provides
    var acProvidesW: Double {
        effectiveACOutputW
    }

    /// How much power the battery provides to the system (discharge only)
    var batteryProvidesW: Double {
        if !effectiveIsOnAC { return systemPowerW }
        if isSupplementalDischarge { return batterySupplementalW }
        return 0
    }

    /// How much power the battery is receiving (charging)
    var batteryChargingW: Double {
        batteryChargeRateW
    }

    var powerSourceDescription: String {
        if isConnectingAC { return String(localized: "AC Connecting") }
        if isBatteryCharging { return String(localized: "AC Charging") }
        if isSupplementalDischarge { return String(localized: "AC + Battery Supplement") }
        if !effectiveIsOnAC { return String(localized: "Battery Discharging") }
        return String(localized: "AC Powered")
    }

    /// Battery is supplementing AC (AC can't provide enough power alone)
    var isSupplementalDischarge: Bool {
        guard !isConnectingAC, effectiveIsOnAC, effectiveACInputW > 0, !isBatteryCharging else { return false }
        if isBatteryDischarging { return true }
        return effectiveACInputW + 0.5 < systemPowerW
    }

    /// How much power the battery contributes during supplemental discharge.
    var batterySupplementalW: Double {
        guard isSupplementalDischarge else { return 0 }
        if batteryPowerW > 0.3 { return batteryPowerW }
        return max(0, systemPowerW - effectiveACInputW)
    }

    /// Primary wattage shown in the popover header.
    var headerPowerW: Double {
        if isConnectingAC || !effectiveIsOnAC || isSupplementalDischarge { return systemPowerW }
        return effectiveACOutputW
    }

    /// Raw wattage for the menu bar — AC charging shows total AC input; all other scenarios show system load.
    var menuBarPowerW: Double {
        if isBatteryCharging { return effectiveACOutputW }
        return systemPowerW
    }

    /// Rounded menu bar power, capped at 99 W.
    var menuBarPowerRoundedW: Int {
        min(99, max(0, Int(menuBarPowerW.rounded())))
    }

    /// Whether actual menu bar power exceeds the display cap.
    var menuBarPowerExceedsCap: Bool {
        menuBarPowerW > 99
    }

    /// Supplemental discharge while on AC — battery still discharging despite charger connected.
    var menuBarPowerShowsBatteryWarning: Bool {
        isSupplementalDischarge
    }

    /// Whether the menu bar should prefix a warning symbol (colors are ignored in the menu bar).
    var menuBarPowerShowsWarning: Bool {
        menuBarPowerShowsBatteryWarning || menuBarPowerExceedsCap
    }

    /// Compact menu bar label text, e.g. "19W" or "⚠ 33W".
    var menuBarPowerText: String {
        let power = "\(menuBarPowerRoundedW)W"
        if menuBarPowerShowsWarning { return "⚠ \(power)" }
        return power
    }

    var validAvgTimeToEmptyMinutes: Int? {
        isValidBatteryTimeMinutes(avgTimeToEmptyMinutes)
    }

    var validAvgTimeToFullMinutes: Int? {
        isValidBatteryTimeMinutes(avgTimeToFullMinutes)
    }

    /// Remaining stored energy (Wh) from coulomb count × pack voltage.
    var remainingEnergyWh: Double? {
        if let remaining = remainingCapacityMAH, let voltage = batteryVoltageMV, remaining > 0, voltage > 0 {
            return Double(remaining) * Double(voltage) / 1_000_000.0
        }
        guard let capacity = fullChargeCapacityMAH ?? rawMaxCapacityMAH ?? nominalChargeCapacityMAH,
              capacity > 0, let voltage = batteryVoltageMV, voltage > 0 else { return nil }
        let soc = stateOfCharge ?? batteryPercent
        guard soc > 0 else { return nil }
        return Double(capacity) * Double(soc) / 100.0 * Double(voltage) / 1_000_000.0
    }

    /// Energy still needed to reach full charge (Wh).
    var energyToFullWh: Double? {
        guard isBatteryCharging, !fullyCharged else { return nil }
        if let remaining = remainingCapacityMAH,
           let full = fullChargeCapacityMAH ?? rawMaxCapacityMAH ?? nominalChargeCapacityMAH,
           full > remaining,
           let voltage = batteryVoltageMV, voltage > 0 {
            return Double(full - remaining) * Double(voltage) / 1_000_000.0
        }
        guard let remaining = remainingEnergyWh,
              let full = fullChargeCapacityMAH ?? rawMaxCapacityMAH ?? nominalChargeCapacityMAH,
              let voltage = batteryVoltageMV, voltage > 0 else { return nil }
        let fullWh = Double(full) * Double(voltage) / 1_000_000.0
        let delta = fullWh - remaining
        return delta > 0 ? delta : nil
    }

    private var dischargePowerForEstimateW: Double? {
        if let smoothed = smoothedDischargePowerW, smoothed >= 0.2 { return smoothed }
        if isSupplementalDischarge {
            let power = max(batterySupplementalW, systemPowerW)
            return power >= 0.2 ? power : nil
        }
        if !effectiveIsOnAC {
            return systemPowerW >= 0.2 ? systemPowerW : nil
        }
        return nil
    }

    private var chargePowerForEstimateW: Double? {
        if let smoothed = smoothedChargePowerW, smoothed >= 0.2 { return smoothed }
        let rate = batteryChargeRateW
        return rate >= 0.2 ? rate : nil
    }

    private var computedTimeToEmptyMinutes: Int? {
        guard !isConnectingAC, !isBatteryCharging else { return nil }
        guard !effectiveIsOnAC || isSupplementalDischarge else { return nil }
        guard let energyWh = remainingEnergyWh, let powerW = dischargePowerForEstimateW else { return nil }
        return Self.minutesFromEnergy(energyWh: energyWh, powerW: powerW)
    }

    private var computedTimeToFullMinutes: Int? {
        guard let energyWh = energyToFullWh, let powerW = chargePowerForEstimateW else { return nil }
        return Self.minutesFromEnergy(energyWh: energyWh, powerW: powerW)
    }

    var estimatedTimeRemainingMinutes: Int? {
        if isBatteryCharging { return validAvgTimeToFullMinutes ?? computedTimeToFullMinutes }
        if !effectiveIsOnAC || isSupplementalDischarge {
            return validAvgTimeToEmptyMinutes ?? computedTimeToEmptyMinutes
        }
        return nil
    }

    /// True when macOS did not supply a valid AvgTimeTo* value and we used our own model.
    var estimatedTimeIsComputed: Bool {
        guard estimatedTimeRemainingMinutes != nil else { return false }
        if isBatteryCharging { return validAvgTimeToFullMinutes == nil }
        return validAvgTimeToEmptyMinutes == nil
    }

    var estimatedTimeRemainingText: String? {
        guard let minutes = estimatedTimeRemainingMinutes else { return nil }
        return Self.formatDuration(minutes: minutes)
    }

    var estimatedTimeRemainingLabel: String {
        isBatteryCharging
            ? String(localized: "Est. Time to Full")
            : String(localized: "Est. Time to Empty")
    }

    private static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    private static func minutesFromEnergy(energyWh: Double, powerW: Double) -> Int? {
        guard powerW >= 0.2, energyWh > 0 else { return nil }
        return cappedMinutes(Int((energyWh / powerW) * 60.0))
    }

    private static func cappedMinutes(_ minutes: Int) -> Int {
        min(max(0, minutes), 99 * 60 + 59)
    }

    var notChargingReasonDescription: String? {
        guard let reason = notChargingReason, reason != 0 else { return nil }
        // Check individual bits/flags
        if reason & 0x01000000 != 0 { return String(localized: "Optimized Battery Charging") }
        if reason & 0x00000002 != 0 { return String(localized: "Temperature Too High") }
        if reason & 0x00000001 != 0 { return String(localized: "Battery Fully Charged") }
        if reason & 0x00000004 != 0 { return String(localized: "Battery Abnormal") }
        if reason & 0x00000080 != 0 { return String(localized: "Charger Power Insufficient") }
        // Fallback for unknown codes
        return String(format: String(localized: "Reason Code %1$@ (0x%2$@)"), "\(reason)", String(format: "%X", reason))
    }

    static let empty = PowerData(
        systemPowerW: 0, batteryPowerW: 0, acInputW: 0,
        acAdapterWattage: 0, batteryPercent: 0,
        isOnAC: false, isCharging: false, fullyCharged: false,
        wallPowerW: nil, adapterEfficiencyLossW: nil,
        systemVoltageMV: nil, systemCurrentMA: nil,
        batteryVoltageMV: nil, batteryAmperageMA: nil,
        batteryTemperatureC: nil, cycleCount: nil,
        adapterDescription: nil, dataSource: .telemetry, timestamp: Date(),
        connectionPhase: .onBattery,
        batteryHealthPercent: nil, designCapacityMAH: nil, rawMaxCapacityMAH: nil,
        nominalChargeCapacityMAH: nil, designCycleCount: nil,
        chargingVoltageMV: nil, chargingCurrentMA: nil,
        notChargingReason: nil, vacVoltageLimit: nil,
        cellVoltagesMV: nil, stateOfCharge: nil, qmaxMAH: nil,
        batteryCellLayout: nil, batteryParallelCellCurrents: nil,
        dailyMinSoc: nil, dailyMaxSoc: nil,
        totalOperatingTimeMin: nil,
        lifetimeMaxTempC: nil, lifetimeMinTempC: nil, lifetimeAvgTempC: nil,
        lifetimeMaxPackVoltageMV: nil, lifetimeMinPackVoltageMV: nil,
        lifetimeMaxChargeCurrentMA: nil, lifetimeMaxDischargeCurrentMA: nil,
        batterySerial: nil, deviceName: nil,
        instantAmperageMA: nil, atCriticalLevel: nil,
        permanentFailureStatus: nil, batteryCellDisconnectCount: nil,
        avgTimeToEmptyMinutes: nil, avgTimeToFullMinutes: nil,
        remainingCapacityMAH: nil, fullChargeCapacityMAH: nil,
        averageSystemPowerW: nil, batteryManufactureDate: nil,
        smoothedDischargePowerW: nil, smoothedChargePowerW: nil
    ) // delegates to private init below (centralized)

    func withConnectionPhase(_ phase: PowerConnectionPhase) -> PowerData {
        withConnectionPhase(phase, smoothedDischargePowerW: smoothedDischargePowerW, smoothedChargePowerW: smoothedChargePowerW)
    }

    func withSmoothedPower(dischargeW: Double?, chargeW: Double?) -> PowerData {
        withConnectionPhase(connectionPhase, smoothedDischargePowerW: dischargeW, smoothedChargePowerW: chargeW)
    }

    private func withConnectionPhase(
        _ phase: PowerConnectionPhase,
        smoothedDischargePowerW: Double?,
        smoothedChargePowerW: Double?
    ) -> PowerData {
        PowerData(
            systemPowerW: systemPowerW, batteryPowerW: batteryPowerW, acInputW: acInputW,
            acAdapterWattage: acAdapterWattage, batteryPercent: batteryPercent,
            isOnAC: isOnAC, isCharging: isCharging, fullyCharged: fullyCharged,
            wallPowerW: wallPowerW, adapterEfficiencyLossW: adapterEfficiencyLossW,
            systemVoltageMV: systemVoltageMV, systemCurrentMA: systemCurrentMA,
            batteryVoltageMV: batteryVoltageMV, batteryAmperageMA: batteryAmperageMA,
            batteryTemperatureC: batteryTemperatureC, cycleCount: cycleCount,
            adapterDescription: adapterDescription, dataSource: dataSource, timestamp: timestamp,
            connectionPhase: phase,
            batteryHealthPercent: batteryHealthPercent, designCapacityMAH: designCapacityMAH,
            rawMaxCapacityMAH: rawMaxCapacityMAH, nominalChargeCapacityMAH: nominalChargeCapacityMAH,
            designCycleCount: designCycleCount, chargingVoltageMV: chargingVoltageMV,
            chargingCurrentMA: chargingCurrentMA, notChargingReason: notChargingReason,
            vacVoltageLimit: vacVoltageLimit, cellVoltagesMV: cellVoltagesMV,
            stateOfCharge: stateOfCharge, qmaxMAH: qmaxMAH,
            batteryCellLayout: batteryCellLayout, batteryParallelCellCurrents: batteryParallelCellCurrents,
            dailyMinSoc: dailyMinSoc,
            dailyMaxSoc: dailyMaxSoc, totalOperatingTimeMin: totalOperatingTimeMin,
            lifetimeMaxTempC: lifetimeMaxTempC, lifetimeMinTempC: lifetimeMinTempC,
            lifetimeAvgTempC: lifetimeAvgTempC, lifetimeMaxPackVoltageMV: lifetimeMaxPackVoltageMV,
            lifetimeMinPackVoltageMV: lifetimeMinPackVoltageMV,
            lifetimeMaxChargeCurrentMA: lifetimeMaxChargeCurrentMA,
            lifetimeMaxDischargeCurrentMA: lifetimeMaxDischargeCurrentMA,
            batterySerial: batterySerial, deviceName: deviceName,
            instantAmperageMA: instantAmperageMA, atCriticalLevel: atCriticalLevel,
            permanentFailureStatus: permanentFailureStatus,
            batteryCellDisconnectCount: batteryCellDisconnectCount,
            avgTimeToEmptyMinutes: avgTimeToEmptyMinutes, avgTimeToFullMinutes: avgTimeToFullMinutes,
            remainingCapacityMAH: remainingCapacityMAH, fullChargeCapacityMAH: fullChargeCapacityMAH,
            averageSystemPowerW: averageSystemPowerW, batteryManufactureDate: batteryManufactureDate,
            smoothedDischargePowerW: smoothedDischargePowerW, smoothedChargePowerW: smoothedChargePowerW
        )
    }
}

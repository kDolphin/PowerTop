import Foundation

enum PowerDataSource {
    case telemetry
    case legacy
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

    // MARK: - Computed properties

    /// Whether we can confidently determine we're on battery (no AC at all).
    /// When ExternalConnected=false AND SystemPowerIn=0, even if IsCharging is stale=true,
    /// we know we're on battery because no AC power is flowing.
    private var clearlyOnBattery: Bool {
        !isOnAC && acInputW == 0
    }

    /// Effective AC status — uses multiple signals with safety overrides for stale data.
    var effectiveIsOnAC: Bool {
        // Safety: if no AC detected at all, ignore stale IsCharging flag
        if clearlyOnBattery { return false }
        if isCharging { return true }
        if acInputW > 0 { return true }
        return isOnAC
    }

    /// Effective AC output in watts.
    /// Uses SystemPowerIn when available; estimates when SystemPowerIn is 0 or outdated.
    var effectiveACOutputW: Double {
        if !effectiveIsOnAC { return 0 }
        if acInputW > 0 { return acInputW }
        // SystemPowerIn hasn't updated yet (e.g. just plugged in), estimate
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
        if clearlyOnBattery { return false }
        if isOnAC && acInputW > systemPowerW + 0.5 { return true }
        if batteryPowerW < -0.3 { return true }
        if isBatteryDischarging { return false }
        if isOnAC && isCharging { return true }
        return false
    }

    /// Battery charge rate in watts (positive value).
    var batteryChargeRateW: Double {
        if !isBatteryCharging { return 0 }
        if batteryPowerW < 0 { return abs(batteryPowerW) }
        if acInputW > systemPowerW { return acInputW - systemPowerW }
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
        if isBatteryCharging { return String(localized: "AC Charging") }
        if isSupplementalDischarge { return String(localized: "AC + Battery Supplement") }
        if !effectiveIsOnAC { return String(localized: "Battery Discharging") }
        return String(localized: "AC Powered")
    }

    /// Battery is supplementing AC (AC can't provide enough power alone)
    var isSupplementalDischarge: Bool {
        guard effectiveIsOnAC, acInputW > 0, !isBatteryCharging else { return false }
        return acInputW + 0.5 < systemPowerW
    }

    /// How much power the battery contributes during supplemental discharge.
    var batterySupplementalW: Double {
        guard isSupplementalDischarge else { return 0 }
        if batteryPowerW > 0.3 { return batteryPowerW }
        return max(0, systemPowerW - acInputW)
    }

    /// Primary wattage shown in the popover header.
    var headerPowerW: Double {
        if !effectiveIsOnAC || isSupplementalDischarge { return systemPowerW }
        if isBatteryCharging { return effectiveACOutputW }
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
        batteryHealthPercent: nil, designCapacityMAH: nil, rawMaxCapacityMAH: nil,
        nominalChargeCapacityMAH: nil, designCycleCount: nil,
        chargingVoltageMV: nil, chargingCurrentMA: nil,
        notChargingReason: nil, vacVoltageLimit: nil,
        cellVoltagesMV: nil, stateOfCharge: nil, qmaxMAH: nil,
        dailyMinSoc: nil, dailyMaxSoc: nil,
        totalOperatingTimeMin: nil,
        lifetimeMaxTempC: nil, lifetimeMinTempC: nil, lifetimeAvgTempC: nil,
        lifetimeMaxPackVoltageMV: nil, lifetimeMinPackVoltageMV: nil,
        lifetimeMaxChargeCurrentMA: nil, lifetimeMaxDischargeCurrentMA: nil,
        batterySerial: nil, deviceName: nil,
        instantAmperageMA: nil, atCriticalLevel: nil,
        permanentFailureStatus: nil, batteryCellDisconnectCount: nil
    )
}

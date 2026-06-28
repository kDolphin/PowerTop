import Foundation
import AppKit
import IOKit
import IOKit.ps
import Observation
import ServiceManagement

@MainActor
@Observable
final class PowerMonitor {
    var currentData: PowerData = .empty
    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    private var timer: Timer?
    private var powerSourceNotifier: CFRunLoopSource?
    private let updateInterval: TimeInterval = 2.0

    init() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func start() {
        updateData()
        scheduleTimer()
        setupPowerSourceNotification()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let notifier = powerSourceNotifier {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), notifier, .commonModes)
            powerSourceNotifier = nil
        }
    }

    @objc private func systemDidSleep() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func systemDidWake() {
        updateData()
        scheduleTimer()
    }

    // MARK: - IOPS Power Source Notification

    private func setupPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            // Multiple delayed refreshes to handle IOKit property update lag.
            // Unplugging takes longer to propagate than plugging in, so we need
            // more refreshes over a longer window.
            for delay: TimeInterval in [0.1, 0.3, 0.6, 1.0, 1.5, 2.0, 3.0, 5.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    monitor.updateData()
                }
            }
        }
        powerSourceNotifier = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue()
        if let notifier = powerSourceNotifier {
            CFRunLoopAddSource(CFRunLoopGetMain(), notifier, .commonModes)
        }
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateData()
            }
        }
    }

    private func updateData() {
        let data = readPowerData()
        self.currentData = data
    }

    // MARK: - IOKit Reading

    private nonisolated func readPowerData() -> PowerData {
        guard let props = getIOServiceProperties(className: "AppleSmartBattery") else {
            return .empty
        }

        // Basic battery info
        let isOnAC = extractBool(from: props, key: "ExternalConnected") ?? false
        let isCharging = extractBool(from: props, key: "IsCharging") ?? false
        let fullyCharged = extractBool(from: props, key: "FullyCharged") ?? false
        let currentCapacity = extractInt(from: props, key: "CurrentCapacity") ?? 0
        let maxCapacity = extractInt(from: props, key: "MaxCapacity") ?? 100
        let batteryPercent = maxCapacity > 0 ? (currentCapacity * 100 / maxCapacity) : 0
        let voltage = extractInt(from: props, key: "Voltage")
        let amperage = extractInt(from: props, key: "Amperage")
        let temperature = extractInt(from: props, key: "Temperature")
        let cycleCount = extractInt(from: props, key: "CycleCount")

        // Device info
        let batterySerial = extractString(from: props, key: "Serial")
        let deviceName = extractString(from: props, key: "DeviceName")
        let instantAmperage = extractInt(from: props, key: "InstantAmperage")
        let atCriticalLevel = extractBool(from: props, key: "AtCriticalLevel")
        let permanentFailure = extractInt(from: props, key: "PermanentFailureStatus")
        let cellDisconnectCount = extractInt(from: props, key: "BatteryCellDisconnectCount")

        // Battery health
        let designCapacity = extractInt(from: props, key: "DesignCapacity")
        let rawMaxCapacity = extractInt(from: props, key: "AppleRawMaxCapacity")
        let nominalChargeCapacity = extractInt(from: props, key: "NominalChargeCapacity")
        let designCycleCount = extractInt(from: props, key: "DesignCycleCount9C")
        let batteryHealthPercent: Int? = {
            guard let design = designCapacity, let raw = rawMaxCapacity, design > 0 else { return nil }
            return min(100, raw * 100 / design)
        }()

        // Adapter details
        let adapterDetails = extractDict(from: props, key: "AdapterDetails")
        let acAdapterWattage = adapterDetails.flatMap { extractInt(from: $0, key: "Watts") } ?? 0
        let adapterDescription = adapterDetails.flatMap { extractString(from: $0, key: "Description") }

        // Charger data
        let chargerData = extractDict(from: props, key: "ChargerData")
        let chargingVoltage = chargerData.flatMap { extractInt(from: $0, key: "ChargingVoltage") }
        let chargingCurrent = chargerData.flatMap { extractInt(from: $0, key: "ChargingCurrent") }
        let notChargingReason = chargerData.flatMap { extractInt(from: $0, key: "NotChargingReason") }
        let vacVoltageLimit = chargerData.flatMap { extractInt(from: $0, key: "VacVoltageLimit") }

        // BatteryData (deep)
        let batteryData = extractDict(from: props, key: "BatteryData")
        let cellVoltages = batteryData.flatMap { extractIntArray(from: $0, key: "CellVoltage") }
        let stateOfCharge = batteryData.flatMap { extractInt(from: $0, key: "StateOfCharge") }
        let qmax = batteryData.flatMap { extractIntArray(from: $0, key: "Qmax") }
        let dailyMinSoc = batteryData.flatMap { extractInt(from: $0, key: "DailyMinSoc") }
        let dailyMaxSoc = batteryData.flatMap { extractInt(from: $0, key: "DailyMaxSoc") }

        // LifetimeData
        let lifetimeData = batteryData.flatMap { extractDict(from: $0, key: "LifetimeData") }
        let totalOpTime = lifetimeData.flatMap { extractInt(from: $0, key: "TotalOperatingTime") }
        let ltMaxTemp = lifetimeData.flatMap { extractInt(from: $0, key: "MaximumTemperature") }
        let ltMinTemp = lifetimeData.flatMap { extractInt(from: $0, key: "MinimumTemperature") }
        let ltAvgTemp = lifetimeData.flatMap { extractInt(from: $0, key: "AverageTemperature") }
        let ltMaxVoltage = lifetimeData.flatMap { extractInt(from: $0, key: "MaximumPackVoltage") }
        let ltMinVoltage = lifetimeData.flatMap { extractInt(from: $0, key: "MinimumPackVoltage") }
        let ltMaxChargeCurrent = lifetimeData.flatMap { extractInt(from: $0, key: "MaximumChargeCurrent") }
        let ltMaxDischargeCurrent = lifetimeData.flatMap { extractInt(from: $0, key: "MaximumDischargeCurrent") }

        // PowerTelemetryData
        let telemetry = extractDict(from: props, key: "PowerTelemetryData")

        let buildResult: (
            _ systemPowerW: Double, _ batteryPowerW: Double,
            _ acInputW: Double,
            _ wallPowerW: Double?, _ adapterLossW: Double?,
            _ sysVoltage: Int?, _ sysCurrent: Int?,
            _ dataSource: PowerDataSource
        ) -> PowerData = { spw, bpw, aiw, wall, loss, sv, sc, ds in
            PowerData(
                systemPowerW: spw, batteryPowerW: bpw, acInputW: aiw,
                acAdapterWattage: acAdapterWattage, batteryPercent: batteryPercent,
                isOnAC: isOnAC, isCharging: isCharging, fullyCharged: fullyCharged,
                wallPowerW: wall, adapterEfficiencyLossW: loss,
                systemVoltageMV: sv, systemCurrentMA: sc,
                batteryVoltageMV: voltage, batteryAmperageMA: amperage,
                batteryTemperatureC: temperature.map { Double($0) / 100.0 },
                cycleCount: cycleCount, adapterDescription: adapterDescription,
                dataSource: ds, timestamp: Date(),
                batteryHealthPercent: batteryHealthPercent,
                designCapacityMAH: designCapacity, rawMaxCapacityMAH: rawMaxCapacity,
                nominalChargeCapacityMAH: nominalChargeCapacity,
                designCycleCount: designCycleCount,
                chargingVoltageMV: chargingVoltage, chargingCurrentMA: chargingCurrent,
                notChargingReason: notChargingReason, vacVoltageLimit: vacVoltageLimit,
                cellVoltagesMV: cellVoltages, stateOfCharge: stateOfCharge,
                qmaxMAH: qmax, dailyMinSoc: dailyMinSoc, dailyMaxSoc: dailyMaxSoc,
                totalOperatingTimeMin: totalOpTime,
                lifetimeMaxTempC: ltMaxTemp, lifetimeMinTempC: ltMinTemp,
                lifetimeAvgTempC: ltAvgTemp,
                lifetimeMaxPackVoltageMV: ltMaxVoltage,
                lifetimeMinPackVoltageMV: ltMinVoltage,
                lifetimeMaxChargeCurrentMA: ltMaxChargeCurrent,
                lifetimeMaxDischargeCurrentMA: ltMaxDischargeCurrent,
                batterySerial: batterySerial, deviceName: deviceName,
                instantAmperageMA: instantAmperage,
                atCriticalLevel: atCriticalLevel,
                permanentFailureStatus: permanentFailure,
                batteryCellDisconnectCount: cellDisconnectCount
            )
        }

        // Calculate actual battery charge rate from top-level IOKit Amperage×Voltage.
        // This is more reliable than BatteryPower in PowerTelemetryData because:
        // 1. BatteryPower suffers from UInt64 overflow (now fixed in extractInt, but still may
        //    not match Amperage×Voltage exactly)
        // 2. SystemLoad includes the charging component, so we must subtract charge rate
        //    to get real system consumption
        let amperageChargeRateW: Double? = {
            guard let a = amperage, let v = voltage, a != 0, v > 0 else { return nil }
            return Double(abs(a)) * Double(v) / 1_000_000.0
        }()

        if let telem = telemetry {
            let systemLoad = extractInt(from: telem, key: "SystemLoad") ?? 0
            let systemPowerIn = extractInt(from: telem, key: "SystemPowerIn") ?? 0
            let batteryPower = extractInt(from: telem, key: "BatteryPower") ?? 0
            let wallEnergy = extractInt(from: telem, key: "WallEnergyEstimate")
            let adapterLoss = extractInt(from: telem, key: "AdapterEfficiencyLoss")
            let sysVoltage = extractInt(from: telem, key: "SystemVoltageIn")
            let sysCurrent = extractInt(from: telem, key: "SystemCurrentIn")

            // SystemPowerIn can retain its last non-zero sample after the
            // adapter is unplugged. ExternalConnected is the authoritative
            // source for whether AC is physically present, so discard stale
            // AC telemetry while running on battery.
            let acInputW = isOnAC ? Double(systemPowerIn) / 1000.0 : 0
            // BatteryPower: positive = discharge, negative (via UInt64 overflow) = charge
            let batteryPowerFromTelemetry = Double(batteryPower) / 1000.0

            // Determine charge rate: prefer Amperage×Voltage, fallback to telemetry BatteryPower
            let chargeRateW: Double
            if isCharging {
                chargeRateW = amperageChargeRateW ?? abs(batteryPowerFromTelemetry)
            } else {
                chargeRateW = 0
            }

            // Calculate systemPowerW:
            // - When charging: SystemLoad includes charging component, so real system consumption
            //   = SystemPowerIn - chargeRate (AC power minus what goes to battery)
            // - When on battery: SystemLoad is negative (IOKit sign convention), use abs or BatteryPower
            // - When on AC not charging: SystemLoad is positive and correct
            var systemPowerW: Double
            if isCharging && acInputW > chargeRateW {
                systemPowerW = acInputW - chargeRateW
            } else if systemLoad < 0 {
                // On battery: SystemLoad is negative, BatteryPower is positive (= discharge rate = system power)
                systemPowerW = batteryPowerFromTelemetry > 0 ? batteryPowerFromTelemetry : abs(Double(systemLoad) / 1000.0)
            } else {
                systemPowerW = Double(systemLoad) / 1000.0
            }

            // Fallback: if systemPowerW is still 0, try SystemVoltage×SystemCurrent
            if systemPowerW == 0, let sv = sysVoltage, let sc = sysCurrent, sv > 0, sc > 0 {
                systemPowerW = Double(sv) * Double(sc) / 1_000_000.0
            }

            // batteryPowerW: negative when charging, positive when discharging
            var batteryPowerW: Double
            if isCharging {
                batteryPowerW = -chargeRateW
            } else {
                batteryPowerW = batteryPowerFromTelemetry
            }

            // On battery with no telemetry, use Amperage×Voltage as system power
            if !isOnAC, systemPowerW == 0, batteryPowerW > 0 {
                systemPowerW = batteryPowerW
            }

            return buildResult(
                systemPowerW, batteryPowerW, acInputW,
                wallEnergy.map { Double($0) / 1000.0 },
                adapterLoss.map { Double($0) / 1000.0 },
                sysVoltage, sysCurrent, .telemetry
            )
        }

        // Fallback: calculate from Amperage x Voltage
        var systemPowerW: Double = 0
        var batteryPowerW: Double = 0
        if let v = voltage, let a = amperage {
            batteryPowerW = Double(a) * Double(v) / 1_000_000.0
            if !isOnAC { systemPowerW = abs(batteryPowerW) }
        }

        return buildResult(systemPowerW, batteryPowerW, 0, nil, nil, nil, nil, .legacy)
    }
}

import Foundation
import AppKit
import IOKit
import IOKit.ps
import Observation
import ServiceManagement

@MainActor
@Observable
final class PowerMonitor {
    private static let showPowerInMenuBarKey = "showPowerInMenuBar"

    var currentData: PowerData = .empty
    /// Bumped on each publish so MenuBarExtra label can refresh (SwiftUI may not redraw otherwise).
    var uiRefreshToken: Int = 0
    var isDataAvailable: Bool = true
    var launchAtLoginError: String?
    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLogin = oldValue
                launchAtLoginError = error.localizedDescription
            }
        }
    }
    var showPowerInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showPowerInMenuBar, forKey: Self.showPowerInMenuBarKey)
        }
    }

    private var timer: Timer?
    private var powerSourceNotifier: CFRunLoopSource?
    private var iopsRetainedContext: UnsafeMutableRawPointer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pendingRefreshWorkItems: [DispatchWorkItem] = []
    private let updateInterval: TimeInterval = 2.0
    private let connectingACTimeout: TimeInterval = 3.0

    private enum MachinePhase: Equatable {
        case onBattery
        case connectingAC(since: Date)
        case onAC
    }

    private var machinePhase: MachinePhase = .onBattery
    private var lastExternalConnected: Bool?
    private var lastUnplugEventAt: Date?
    private var timeEstimator = BatteryTimeEstimator()

    init() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        showPowerInMenuBar = UserDefaults.standard.bool(forKey: Self.showPowerInMenuBarKey)
    }

    func refreshNow() {
        updateData()
    }

    func start() {
        guard timer == nil else { return }
        let (raw, available) = readPowerData()
        isDataAvailable = available
        lastExternalConnected = raw.isOnAC
        machinePhase = raw.isOnAC ? .onAC : .onBattery
        publishDisplayData(from: raw)
        scheduleTimer()
        setupPowerSourceNotification()

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSystemSleep()
                }
            }
        )
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSystemWake()
                }
            }
        )
    }

    func stop() {
        timeEstimator.reset()
        timer?.invalidate()
        timer = nil
        cancelPendingRefreshes()
        if let notifier = powerSourceNotifier {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), notifier, .commonModes)
            powerSourceNotifier = nil
        }
        if let ctx = iopsRetainedContext {
            Unmanaged<PowerMonitor>.fromOpaque(ctx).release()
            iopsRetainedContext = nil
        }
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func handleSystemSleep() {
        timeEstimator.reset()
        timer?.invalidate()
        timer = nil
    }

    private func handleSystemWake() {
        updateData()
        if timer == nil {
            scheduleTimer()
        }
    }

    // MARK: - IOPS Power Source Notification

    private func setupPowerSourceNotification() {
        let retained = Unmanaged.passRetained(self)
        iopsRetainedContext = retained.toOpaque()
        let context = retained.toOpaque()

        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.handlePowerSourceEvent()
            }
        }
        powerSourceNotifier = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue()
        if let notifier = powerSourceNotifier {
            CFRunLoopAddSource(CFRunLoopGetMain(), notifier, .commonModes)
        }
    }

    private func scheduleCoalescedRefreshes() {
        cancelPendingRefreshes()
        for delay: TimeInterval in [0.1, 0.3, 0.6, 1.0, 1.5, 2.0, 3.0, 5.0] {
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.updateData()
                }
            }
            pendingRefreshWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelPendingRefreshes() {
        pendingRefreshWorkItems.forEach { $0.cancel() }
        pendingRefreshWorkItems.removeAll()
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateData()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func updateData() {
        let (raw, available) = readPowerData()
        isDataAvailable = available
        publishDisplayData(from: raw)
    }

    private func handlePowerSourceEvent() {
        guard let connected = readExternalConnected() else {
            updateData()
            return
        }

        let previous = lastExternalConnected
        lastExternalConnected = connected

        if let prev = previous, prev != connected {
            if connected {
                machinePhase = .connectingAC(since: Date())
            } else {
                machinePhase = .onBattery
                lastUnplugEventAt = Date()
            }
        }
        updateData()
        scheduleCoalescedRefreshes()
    }

    private func publishDisplayData(from raw: PowerData) {
        advanceMachinePhase(with: raw)
        let phased = raw.withConnectionPhase(displayConnectionPhase())
        let smoothed = timeEstimator.smoothedPower(for: phased)
        currentData = phased.withSmoothedPower(dischargeW: smoothed.dischargeW, chargeW: smoothed.chargeW)
        uiRefreshToken &+= 1
    }

    private func advanceMachinePhase(with raw: PowerData) {
        switch machinePhase {
        case .onBattery:
            if let t = lastUnplugEventAt, Date().timeIntervalSince(t) < 1.5 {
                return
            }
            if raw.isOnAC {
                machinePhase = .connectingAC(since: Date())
                lastUnplugEventAt = nil
            }

        case .connectingAC(let since):
            if !raw.isOnAC {
                machinePhase = .onBattery
            } else if hasResolvedACStateDuringConnecting(raw)
                || Date().timeIntervalSince(since) >= connectingACTimeout {
                machinePhase = .onAC
                lastUnplugEventAt = nil
            }

        case .onAC:
            if !raw.isOnAC {
                machinePhase = .onBattery
            }
        }
    }

    /// During AC connecting, stale pre-unplug SystemPowerIn must not alone prove convergence.
    private func hasResolvedACStateDuringConnecting(_ raw: PowerData) -> Bool {
        guard raw.isOnAC else { return false }

        if raw.isCharging && raw.batteryPowerW < -0.3 { return true }
        if let amp = raw.batteryAmperageMA, amp < -50 { return true }
        if let cc = raw.chargingCurrentMA, cc > 0, raw.batteryPowerW < -0.3 { return true }

        guard raw.acInputW > 0.3, raw.systemPowerW > 0 else { return false }
        if raw.batteryPowerW < -0.3 { return true }
        if raw.acInputW >= raw.systemPowerW - 0.5 { return true }
        return false
    }

    private func displayConnectionPhase() -> PowerConnectionPhase {
        switch machinePhase {
        case .onBattery: return .onBattery
        case .connectingAC: return .connectingAC
        case .onAC: return .onAC
        }
    }

    private nonisolated func readExternalConnected() -> Bool? {
        guard let props = getIOServiceProperties(className: "AppleSmartBattery") else { return nil }
        return extractBool(from: props, key: "ExternalConnected")
    }

    // MARK: - IOKit Reading

    private nonisolated func readPowerData() -> (PowerData, Bool) {
        guard let props = getIOServiceProperties(className: "AppleSmartBattery") else {
            return (.empty, false)
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
        let cycleCount = extractInt(from: props, key: "CycleCount")

        // Device info
        let batterySerial = extractString(from: props, key: "Serial")
        let deviceName = extractString(from: props, key: "DeviceName")
        let instantAmperage = extractInt(from: props, key: "InstantAmperage")
        let atCriticalLevel = extractBool(from: props, key: "AtCriticalLevel")
        let permanentFailure = extractInt(from: props, key: "PermanentFailureStatus")
        let cellDisconnectCount = extractInt(from: props, key: "BatteryCellDisconnectCount")

        // Battery health — DesignCapacity / FCC / Nominal often live in BatteryData on Apple Silicon.
        let capacitySnapshot = readBatteryCapacitySnapshot(from: props)
        let designCapacity = capacitySnapshot.designCapacityMAH
        let rawMaxCapacity = capacitySnapshot.rawMaxCapacityMAH
        let nominalChargeCapacity = capacitySnapshot.nominalChargeCapacityMAH
        let batteryHealthPercent = capacitySnapshot.healthPercent
        let temperature = capacitySnapshot.temperatureCentidegrees
        let designCycleCount = extractInt(from: props, key: "DesignCycleCount9C")
            ?? extractInt(from: props, key: "DesignCycleCount70")

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

        var avgSysPowerW: Double?

        // BatteryData (deep)
        let batteryData = extractDict(from: props, key: "BatteryData")
        let cellTelemetry = readBatteryCellTelemetry(packBatteryData: batteryData)
        let cellVoltages = cellTelemetry?.voltagesMV
        let qmax = cellTelemetry?.qmaxMAH
        let batteryCellLayout = cellTelemetry?.layout
        let batteryParallelCellCurrents = cellTelemetry?.parallelCellCurrents
        let stateOfCharge = capacitySnapshot.stateOfCharge
        let dailyMinSoc = capacitySnapshot.dailyMinSoc
        let dailyMaxSoc = capacitySnapshot.dailyMaxSoc
        let remainingCapacity = capacitySnapshot.remainingCapacityMAH
        let fullChargeCapacityBD = capacitySnapshot.fullChargeCapacityMAH
        let avgTimeToEmpty = batteryData.flatMap { extractInt(from: $0, key: "AvgTimeToEmpty") }
            ?? extractInt(from: props, key: "AvgTimeToEmpty")
        let avgTimeToFull = batteryData.flatMap { extractInt(from: $0, key: "AvgTimeToFull") }
            ?? extractInt(from: props, key: "AvgTimeToFull")
        let manufactureDateStr = parseBatteryManufactureDate(from: props)

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
                batteryTemperatureC: temperature.map { TemperatureUnits.instantCelsius(fromCentidegrees: $0) },
                cycleCount: cycleCount, adapterDescription: adapterDescription,
                dataSource: ds, timestamp: Date(),
                connectionPhase: .onBattery,
                batteryHealthPercent: batteryHealthPercent,
                designCapacityMAH: designCapacity, rawMaxCapacityMAH: rawMaxCapacity,
                nominalChargeCapacityMAH: nominalChargeCapacity,
                designCycleCount: designCycleCount,
                chargingVoltageMV: chargingVoltage, chargingCurrentMA: chargingCurrent,
                notChargingReason: notChargingReason, vacVoltageLimit: vacVoltageLimit,
                cellVoltagesMV: cellVoltages, stateOfCharge: stateOfCharge,
                qmaxMAH: qmax, batteryCellLayout: batteryCellLayout,
                batteryParallelCellCurrents: batteryParallelCellCurrents,
                dailyMinSoc: dailyMinSoc, dailyMaxSoc: dailyMaxSoc,
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
                batteryCellDisconnectCount: cellDisconnectCount,
                avgTimeToEmptyMinutes: avgTimeToEmpty, avgTimeToFullMinutes: avgTimeToFull,
                remainingCapacityMAH: remainingCapacity, fullChargeCapacityMAH: fullChargeCapacityBD,
                averageSystemPowerW: avgSysPowerW, batteryManufactureDate: manufactureDateStr,
                smoothedDischargePowerW: nil, smoothedChargePowerW: nil
            )
        }

        // IOKit sign convention: Amperage > 0 = discharge, < 0 = charge.
        let amperagePowerW: Double? = {
            guard let a = amperage, let v = voltage, a != 0, v > 0 else { return nil }
            return Double(a) * Double(v) / 1_000_000.0
        }()

        if let telem = telemetry {
            let systemLoad = extractInt(from: telem, key: "SystemLoad") ?? 0
            let systemPowerIn = extractInt(from: telem, key: "SystemPowerIn") ?? 0
            let batteryPower = extractInt(from: telem, key: "BatteryPower") ?? 0
            let wallEnergy = extractInt(from: telem, key: "WallEnergyEstimate")
            let adapterLoss = extractInt(from: telem, key: "AdapterEfficiencyLoss")
            let sysVoltage = extractInt(from: telem, key: "SystemVoltageIn")
            let sysCurrent = extractInt(from: telem, key: "SystemCurrentIn")

            // Average system power from accumulators
            let accumLoad = extractInt(from: telem, key: "AccumulatedSystemLoad") ?? 0
            let loadCount = extractInt(from: telem, key: "SystemLoadAccumulatorCount") ?? 0
            avgSysPowerW = loadCount > 0 ? Double(accumLoad) / Double(loadCount) / 1000.0 : nil

            let reportedACInputW = Double(systemPowerIn) / 1000.0
            // Ignore stale SystemPowerIn after unplug — ExternalConnected is authoritative.
            let acInputW = isOnAC ? reportedACInputW : 0
            let systemLoadW = Double(systemLoad) / 1000.0
            // BatteryPower: positive = discharge, negative = charge
            let batteryPowerFromTelemetry = Double(batteryPower) / 1000.0

            let flow = resolveBatteryFlow(
                isOnAC: isOnAC,
                isChargingFlag: isCharging,
                acInputW: acInputW,
                systemLoadW: systemLoadW,
                amperagePowerW: amperagePowerW,
                batteryPowerFromTelemetry: batteryPowerFromTelemetry
            )

            let (systemPowerW, batteryPowerW) = computePowerMetrics(
                flow: flow,
                isOnAC: isOnAC,
                acInputW: acInputW,
                systemLoadW: systemLoadW,
                batteryPowerFromTelemetry: batteryPowerFromTelemetry,
                sysVoltage: sysVoltage,
                sysCurrent: sysCurrent
            )

            return (
                buildResult(
                    systemPowerW, batteryPowerW, acInputW,
                    wallEnergy.map { Double($0) / 1000.0 },
                    adapterLoss.map { Double($0) / 1000.0 },
                    sysVoltage, sysCurrent, .telemetry
                ),
                true
            )
        }

        // Fallback: calculate from signed Amperage × Voltage
        var systemPowerW: Double = 0
        var batteryPowerW: Double = 0
        if let signedPower = amperagePowerW {
            batteryPowerW = signedPower
            if !isOnAC {
                systemPowerW = abs(signedPower)
            } else if signedPower < 0 {
                systemPowerW = 0
            } else {
                systemPowerW = signedPower
            }
        }

        return (buildResult(systemPowerW, batteryPowerW, 0, nil, nil, nil, nil, .legacy), true)
    }

    private enum BatteryFlow {
        case charging(rateW: Double)
        case discharging(rateW: Double)
        case idle
    }

    /// Resolves actual battery direction using amperage/telemetry signs, with IsCharging as fallback only.
    private nonisolated func resolveBatteryFlow(
        isOnAC: Bool,
        isChargingFlag: Bool,
        acInputW: Double,
        systemLoadW: Double,
        amperagePowerW: Double?,
        batteryPowerFromTelemetry: Double
    ) -> BatteryFlow {
        let powerThreshold = 0.3

        // Energy balance on AC: input > load → surplus charges battery.
        if isOnAC, acInputW > systemLoadW + powerThreshold {
            if let ampPower = amperagePowerW, ampPower < -powerThreshold {
                return .charging(rateW: abs(ampPower))
            }
            if batteryPowerFromTelemetry < -powerThreshold {
                return .charging(rateW: abs(batteryPowerFromTelemetry))
            }
            return .charging(rateW: acInputW - systemLoadW)
        }

        // Energy balance on AC: load > input → battery supplements the system.
        if isOnAC, systemLoadW > acInputW + powerThreshold {
            if let ampPower = amperagePowerW, ampPower > powerThreshold {
                let rate = batteryPowerFromTelemetry > powerThreshold
                    ? batteryPowerFromTelemetry
                    : ampPower
                return .discharging(rateW: rate)
            }
            if batteryPowerFromTelemetry > powerThreshold {
                return .discharging(rateW: batteryPowerFromTelemetry)
            }
            return .discharging(rateW: systemLoadW - acInputW)
        }

        if let ampPower = amperagePowerW {
            if ampPower > powerThreshold {
                return .discharging(rateW: ampPower)
            }
            if isOnAC, ampPower < -powerThreshold {
                return .charging(rateW: abs(ampPower))
            }
        }

        if batteryPowerFromTelemetry > powerThreshold {
            return .discharging(rateW: batteryPowerFromTelemetry)
        }
        if batteryPowerFromTelemetry < -powerThreshold {
            return .charging(rateW: abs(batteryPowerFromTelemetry))
        }

        if isOnAC && isChargingFlag {
            if let ampPower = amperagePowerW, ampPower < 0 {
                return .charging(rateW: abs(ampPower))
            }
        }

        return .idle
    }

    private nonisolated func computePowerMetrics(
        flow: BatteryFlow,
        isOnAC: Bool,
        acInputW: Double,
        systemLoadW: Double,
        batteryPowerFromTelemetry: Double,
        sysVoltage: Int?,
        sysCurrent: Int?
    ) -> (systemPowerW: Double, batteryPowerW: Double) {
        var systemPowerW: Double = 0
        var batteryPowerW: Double = 0

        switch flow {
        case .charging(let rateW):
            batteryPowerW = -rateW
            if isOnAC, acInputW > rateW {
                systemPowerW = acInputW - rateW
            } else if systemLoadW > 0 {
                systemPowerW = systemLoadW
            } else if isOnAC {
                systemPowerW = max(0, acInputW - rateW)
            }

        case .discharging(let rateW):
            batteryPowerW = rateW
            if isOnAC {
                if systemLoadW > 0 {
                    systemPowerW = systemLoadW
                } else {
                    systemPowerW = acInputW + rateW
                }
            } else if systemLoadW < 0 {
                systemPowerW = abs(systemLoadW)
            } else {
                systemPowerW = rateW
            }

        case .idle:
            batteryPowerW = batteryPowerFromTelemetry
            if !isOnAC {
                if systemLoadW > 0 {
                    systemPowerW = systemLoadW
                } else if systemLoadW < 0 {
                    systemPowerW = abs(systemLoadW)
                } else if batteryPowerFromTelemetry > 0 {
                    systemPowerW = batteryPowerFromTelemetry
                } else if batteryPowerFromTelemetry < 0 {
                    systemPowerW = abs(batteryPowerFromTelemetry)
                }
            } else if systemLoadW > 0 {
                systemPowerW = systemLoadW
            } else {
                systemPowerW = acInputW
            }
        }

        if systemPowerW == 0, let sv = sysVoltage, let sc = sysCurrent, sv > 0, sc > 0 {
            systemPowerW = Double(sv) * Double(sc) / 1_000_000.0
        }

        if !isOnAC, systemPowerW == 0, systemLoadW > 0 {
            systemPowerW = systemLoadW
        }

        if !isOnAC, systemPowerW == 0, batteryPowerW > 0 {
            systemPowerW = batteryPowerW
        }

        return (systemPowerW, batteryPowerW)
    }
}
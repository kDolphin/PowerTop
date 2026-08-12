import Foundation
import IOKit

func getIOServiceProperties(className: String) -> [String: Any]? {
    let matching = IOServiceMatching(className)
    var iterator: io_iterator_t = 0

    let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
    guard kr == KERN_SUCCESS else { return nil }
    defer { IOObjectRelease(iterator) }

    let service = IOIteratorNext(iterator)
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }

    var properties: Unmanaged<CFMutableDictionary>?
    let propResult = IORegistryEntryCreateCFProperties(
        service,
        &properties,
        kCFAllocatorDefault,
        0
    )
    guard propResult == KERN_SUCCESS, let props = properties?.takeRetainedValue() else {
        return nil
    }

    return props as? [String: Any]
}

func extractInt(from dict: [String: Any], key: String) -> Int? {
    guard let value = dict[key] else { return nil }
    if let intVal = value as? Int { return intVal }
    // Handle UInt64 overflow: IOKit stores some signed values (e.g. BatteryPower) as UInt64.
    // A negative value like -15034 gets stored as 18446744073709536582 (UInt64).
    // `as? Int` fails because it exceeds Int64.max, so we must use bitPattern conversion.
    if let uint64Val = value as? UInt64 {
        return Int(Int64(bitPattern: uint64Val))
    }
    if let numVal = value as? NSNumber { return numVal.intValue }
    return nil
}

func extractBool(from dict: [String: Any], key: String) -> Bool? {
    guard let value = dict[key] else { return nil }
    if let boolVal = value as? Bool { return boolVal }
    if let numVal = value as? NSNumber { return numVal.boolValue }
    return nil
}

func extractString(from dict: [String: Any], key: String) -> String? {
    return dict[key] as? String
}

func extractDict(from dict: [String: Any], key: String) -> [String: Any]? {
    return dict[key] as? [String: Any]
}

func extractIntArray(from dict: [String: Any], key: String) -> [Int]? {
    guard let value = dict[key] else { return nil }
    if let arr = value as? [Int] { return arr }
    if let arr = value as? [NSNumber] { return arr.map { $0.intValue } }
    return nil
}

/// Reads a date only from explicit `ManufactureDate` properties.
///
/// `ManufacturerData` is manufacturer-defined data and must not be interpreted as a date.
func readBatteryManufactureDate(from batteryProperties: [String: Any]) -> String? {
    if let date = parseBatteryManufactureDate(from: batteryProperties) {
        return date
    }
    guard let packProperties = getIOServiceProperties(className: "AppleSmartBatteryPack") else {
        return nil
    }
    return parseBatteryManufactureDate(from: packProperties)
}

func parseBatteryManufactureDate(from properties: [String: Any]) -> String? {
    let batteryData = extractDict(from: properties, key: "BatteryData")
    guard let encodedDate = extractInt(from: properties, key: "ManufactureDate")
        ?? batteryData.flatMap({ extractInt(from: $0, key: "ManufactureDate") }) else {
        return nil
    }
    return formatBatteryManufactureDate(encodedDate)
}

/// Decodes the six reversed ASCII digits used by recent Apple Silicon battery packs.
///
/// The decoded digits are `YYMMDD`, where `YY` is years since 1992. Apple does not
/// document this representation, so reject values that are not exact, valid, and non-future.
func formatBatteryManufactureDate(
    _ encodedDate: Int,
    relativeTo currentDate: Date = Date()
) -> String? {
    guard encodedDate > 0 else { return nil }
    let rawValue = UInt64(encodedDate)
    guard rawValue <= 0xFFFF_FFFF_FFFF else { return nil }

    func asciiDigit(at shift: Int) -> Int? {
        let byte = UInt8((rawValue >> shift) & 0xFF)
        guard (48...57).contains(byte) else { return nil }
        return Int(byte - 48)
    }

    guard let yearTens = asciiDigit(at: 0),
          let yearOnes = asciiDigit(at: 8),
          let monthTens = asciiDigit(at: 16),
          let monthOnes = asciiDigit(at: 24),
          let dayTens = asciiDigit(at: 32),
          let dayOnes = asciiDigit(at: 40) else {
        return nil
    }

    let year = 1992 + yearTens * 10 + yearOnes
    let month = monthTens * 10 + monthOnes
    let day = dayTens * 10 + dayOnes

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = year
    components.month = month
    components.day = day

    guard let date = calendar.date(from: components), date <= currentDate else { return nil }
    let validated = calendar.dateComponents([.year, .month, .day], from: date)
    guard validated.year == year, validated.month == month, validated.day == day else {
        return nil
    }

    return String(format: "%04d-%02d-%02d", year, month, day)
}

/// Capacity and health fields from `AppleSmartBattery`; many values live under `BatteryData` on Apple Silicon.
struct BatteryCapacitySnapshot: Equatable {
    let designCapacityMAH: Int?
    let fullChargeCapacityMAH: Int?
    let rawMaxCapacityMAH: Int?
    let nominalChargeCapacityMAH: Int?
    let remainingCapacityMAH: Int?
    let stateOfCharge: Int?
    let dailyMinSoc: Int?
    let dailyMaxSoc: Int?
    let temperatureCentidegrees: Int?

    var healthPercent: Int? {
        guard let design = designCapacityMAH, design > 0 else { return nil }
        let current = rawMaxCapacityMAH ?? fullChargeCapacityMAH ?? nominalChargeCapacityMAH
        guard let current, current > 0 else { return nil }
        return min(100, current * 100 / design)
    }
}

func readBatteryCapacitySnapshot(from props: [String: Any]) -> BatteryCapacitySnapshot {
    let batteryData = extractDict(from: props, key: "BatteryData")

    func packOrBatteryData(_ key: String) -> Int? {
        extractInt(from: props, key: key)
            ?? batteryData.flatMap { extractInt(from: $0, key: key) }
    }

    let bankBatteryData = readFirstBankBatteryData()
    return BatteryCapacitySnapshot(
        designCapacityMAH: packOrBatteryData("DesignCapacity"),
        fullChargeCapacityMAH: batteryData.flatMap { extractInt(from: $0, key: "FullChargeCapacity") }
            ?? extractInt(from: props, key: "FullChargeCapacity"),
        rawMaxCapacityMAH: packOrBatteryData("AppleRawMaxCapacity")
            ?? bankBatteryData.flatMap { extractInt(from: $0, key: "AppleRawMaxCapacity") },
        nominalChargeCapacityMAH: packOrBatteryData("NominalChargeCapacity"),
        remainingCapacityMAH: batteryData.flatMap { extractInt(from: $0, key: "RemainingCapacity") }
            ?? extractInt(from: props, key: "RemainingCapacity"),
        stateOfCharge: batteryData.flatMap { extractInt(from: $0, key: "StateOfCharge") }
            ?? extractInt(from: props, key: "StateOfCharge")
            ?? bankBatteryData.flatMap { extractInt(from: $0, key: "StateOfCharge") },
        dailyMinSoc: batteryData.flatMap { extractInt(from: $0, key: "DailyMinSoc") }
            ?? extractInt(from: props, key: "DailyMinSoc")
            ?? bankBatteryData.flatMap { extractInt(from: $0, key: "DailyMinSoc") },
        dailyMaxSoc: batteryData.flatMap { extractInt(from: $0, key: "DailyMaxSoc") }
            ?? extractInt(from: props, key: "DailyMaxSoc")
            ?? bankBatteryData.flatMap { extractInt(from: $0, key: "DailyMaxSoc") },
        temperatureCentidegrees: packOrBatteryData("Temperature")
            ?? bankBatteryData.flatMap { extractInt(from: $0, key: "Temperature") }
    )
}

private func readFirstBankBatteryData() -> [String: Any]? {
    let matching = IOServiceMatching("AppleSmartBatteryBank")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return nil
    }
    defer { IOObjectRelease(iterator) }

    while true {
        let service = IOIteratorNext(iterator)
        guard service != 0 else { break }
        defer { IOObjectRelease(service) }
        guard let props = copyServiceProperties(service),
              let batteryData = extractDict(from: props, key: "BatteryData") else { continue }
        return batteryData
    }
    return nil
}

/// macOS uses 65535 as an invalid sentinel for battery time estimates.
func isValidBatteryTimeMinutes(_ minutes: Int?) -> Int? {
    guard let minutes, minutes > 0, minutes < 65_535 else { return nil }
    return minutes
}

struct BatteryCellTelemetry: Equatable {
    let layout: BatteryCellTelemetryLayout
    let voltagesMV: [Int]
    let qmaxMAH: [Int]
    let parallelCellCurrents: [BatteryParallelCellCurrent]
}

private struct BatteryBankReading {
    let bankID: Int
    let voltageMV: Int?
    let qmaxMAH: Int?
}

private struct BatteryCellSlot {
    let bankID: Int
    let cellID: Int
}

/// Reads cell telemetry. Apple Silicon exposes series groups via bank nodes; pack-level arrays are a fallback when each entry is a distinct physical cell.
func readBatteryCellTelemetry(packBatteryData: [String: Any]?) -> BatteryCellTelemetry? {
    let banks = readBatteryBankReadings()
    if !banks.isEmpty {
        let sortedBanks = banks.sorted { $0.bankID < $1.bankID }
        let voltages = sortedBanks.compactMap(\.voltageMV)
        let qmaxValues = sortedBanks.compactMap(\.qmaxMAH)
        if !voltages.isEmpty, voltages.count == qmaxValues.count {
            let parallelCells = readBatteryParallelCellCurrents()
            let cellSlots = readBatteryCellSlots()
            let parallelCount = inferredParallelCount(parallelCells: parallelCells, cellSlots: cellSlots)
            let parallelCountKnown = parallelCount > 1
                || !parallelCells.isEmpty
                || !cellSlots.isEmpty

            return BatteryCellTelemetry(
                layout: .seriesParallel(
                    seriesCount: voltages.count,
                    parallelCount: parallelCount,
                    parallelCountKnown: parallelCountKnown
                ),
                voltagesMV: voltages,
                qmaxMAH: qmaxValues,
                parallelCellCurrents: parallelCells
            )
        }
    }

    if let pack = packBatteryData,
       let voltages = extractIntArray(from: pack, key: "CellVoltage"),
       let qmax = extractIntArray(from: pack, key: "Qmax"),
       !voltages.isEmpty,
       voltages.count == qmax.count {
        return BatteryCellTelemetry(
            layout: .perCellArrays,
            voltagesMV: voltages,
            qmaxMAH: qmax,
            parallelCellCurrents: []
        )
    }

    return nil
}

private func inferredParallelCount(
    parallelCells: [BatteryParallelCellCurrent],
    cellSlots: [BatteryCellSlot]
) -> Int {
    if !parallelCells.isEmpty {
        return Dictionary(grouping: parallelCells, by: \.bankID).values.map(\.count).max() ?? 1
    }
    if !cellSlots.isEmpty {
        return Dictionary(grouping: cellSlots, by: \.bankID).values.map(\.count).max() ?? 1
    }
    return 1
}

private func readBatteryBankReadings() -> [BatteryBankReading] {
    let matching = IOServiceMatching("AppleSmartBatteryBank")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return []
    }
    defer { IOObjectRelease(iterator) }

    var results: [BatteryBankReading] = []
    while true {
        let service = IOIteratorNext(iterator)
        guard service != 0 else { break }
        defer { IOObjectRelease(service) }

        guard let props = copyServiceProperties(service) else { continue }
        let bankID = extractInt(from: props, key: "BankID") ?? results.count
        let batteryData = extractDict(from: props, key: "BatteryData")
        let voltageMV = batteryData.flatMap { extractInt(from: $0, key: "CellVoltage") }
        let qmaxMAH = batteryData.flatMap { extractInt(from: $0, key: "Qmax") }
        if voltageMV != nil || qmaxMAH != nil {
            results.append(BatteryBankReading(bankID: bankID, voltageMV: voltageMV, qmaxMAH: qmaxMAH))
        }
    }
    return results
}

private func readBatteryCellSlots() -> [BatteryCellSlot] {
    let matching = IOServiceMatching("AppleSmartBatteryCell")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return []
    }
    defer { IOObjectRelease(iterator) }

    var results: [BatteryCellSlot] = []
    while true {
        let service = IOIteratorNext(iterator)
        guard service != 0 else { break }
        defer { IOObjectRelease(service) }

        guard let props = copyServiceProperties(service) else { continue }
        guard let bankID = extractInt(from: props, key: "BankID"),
              let cellID = extractInt(from: props, key: "CellID") else { continue }
        results.append(BatteryCellSlot(bankID: bankID, cellID: cellID))
    }
    return results.sorted { lhs, rhs in
        if lhs.bankID == rhs.bankID { return lhs.cellID < rhs.cellID }
        return lhs.bankID < rhs.bankID
    }
}

private func readBatteryParallelCellCurrents() -> [BatteryParallelCellCurrent] {
    let matching = IOServiceMatching("AppleSmartBatteryCell")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
        return []
    }
    defer { IOObjectRelease(iterator) }

    var results: [BatteryParallelCellCurrent] = []
    while true {
        let service = IOIteratorNext(iterator)
        guard service != 0 else { break }
        defer { IOObjectRelease(service) }

        guard let props = copyServiceProperties(service) else { continue }
        guard let bankID = extractInt(from: props, key: "BankID"),
              let cellID = extractInt(from: props, key: "CellID") else { continue }
        let cellData = extractDict(from: props, key: "CellData")
        guard let currentMA = cellData.flatMap({ extractInt(from: $0, key: "CellCurrent") }) else { continue }
        results.append(BatteryParallelCellCurrent(bankID: bankID, cellID: cellID, currentMA: currentMA))
    }
    return results.sorted { lhs, rhs in
        if lhs.bankID == rhs.bankID { return lhs.cellID < rhs.cellID }
        return lhs.bankID < rhs.bankID
    }
}

private func copyServiceProperties(_ service: io_service_t) -> [String: Any]? {
    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let props = properties?.takeRetainedValue() else {
        return nil
    }
    return props as? [String: Any]
}

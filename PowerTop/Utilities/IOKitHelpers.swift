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

/// Parses YYWW manufacture code embedded in binary `ManufacturerData` (e.g. 1916 → 2019 W16).
func parseBatteryManufactureDate(from props: [String: Any]) -> String? {
    let raw = props["ManufacturerData"]
    let data: Data?
    if let blob = raw as? Data {
        data = blob
    } else if let blob = raw as? NSData {
        data = blob as Data
    } else {
        return nil
    }
    guard let data, data.count >= 4 else { return nil }

    let bytes = [UInt8](data)
    for index in 0...(bytes.count - 4) {
        let slice = bytes[index..<(index + 4)]
        guard slice.allSatisfy({ (48...57).contains($0) }) else { continue }
        guard let code = String(bytes: slice, encoding: .ascii) else { continue }
        let yy = Int(code.prefix(2)) ?? 0
        let ww = Int(code.suffix(2)) ?? 0
        guard (10...40).contains(yy), (1...53).contains(ww) else { continue }
        let year = 2000 + yy
        return String(format: String(localized: "Manufacture Week Format"), year, ww)
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

/// Reads cell telemetry. Pack-level arrays map 1:1 to physical cells; bank nodes expose series-group V/Qmax plus per-parallel-cell current.
func readBatteryCellTelemetry(packBatteryData: [String: Any]?) -> BatteryCellTelemetry? {
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

    let banks = readBatteryBankReadings()
    guard !banks.isEmpty else { return nil }

    let sortedBanks = banks.sorted { $0.bankID < $1.bankID }
    let voltages = sortedBanks.compactMap(\.voltageMV)
    let qmaxValues = sortedBanks.compactMap(\.qmaxMAH)
    guard !voltages.isEmpty, voltages.count == qmaxValues.count else { return nil }

    let parallelCells = readBatteryParallelCellCurrents()
    let parallelCount = parallelCells.isEmpty
        ? 1
        : (Dictionary(grouping: parallelCells, by: \.bankID).values.map(\.count).max() ?? 1)

    return BatteryCellTelemetry(
        layout: .seriesParallel(seriesCount: voltages.count, parallelCount: parallelCount),
        voltagesMV: voltages,
        qmaxMAH: qmaxValues,
        parallelCellCurrents: parallelCells
    )
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

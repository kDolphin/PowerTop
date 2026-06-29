import Foundation

/// Documented IOKit temperature unit conversions for AppleSmartBattery fields.
enum TemperatureUnits {
    /// Instant pack temperature (`Temperature`): centidegrees Celsius (÷ 100).
    static func instantCelsius(fromCentidegrees value: Int) -> Double {
        Double(value) / 100.0
    }

    /// Lifetime max/min (`MaximumTemperature`, `MinimumTemperature`): whole degrees Celsius.
    static func lifetimeCelsius(fromWholeDegrees value: Int) -> Int {
        value
    }

    /// Lifetime average (`AverageTemperature`): decidegrees Celsius (÷ 10).
    static func lifetimeAvgCelsius(fromDecidegrees value: Int) -> Double {
        Double(value) / 10.0
    }
}
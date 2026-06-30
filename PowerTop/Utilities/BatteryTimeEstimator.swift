import Foundation

/// Smooths instantaneous power for battery time estimates when macOS no longer reports AvgTimeToEmpty/Full.
struct BatteryTimeEstimator {
    private var dischargeEMA: Double?
    private var chargeEMA: Double?
    private var lastMode: Mode?

    private enum Mode: Equatable {
        case discharging
        case charging
    }

    /// ~60 s effective window at 2 s sampling.
    private let emaAlpha = 0.065

    mutating func reset() {
        dischargeEMA = nil
        chargeEMA = nil
        lastMode = nil
    }

    /// Returns smoothed discharge/charge power (watts) for the current display snapshot.
    mutating func smoothedPower(for data: PowerData) -> (dischargeW: Double?, chargeW: Double?) {
        guard !data.isConnectingAC else {
            reset()
            return (nil, nil)
        }

        if data.isBatteryCharging, !data.fullyCharged {
            return (nil, updateChargeEMA(for: data))
        }

        if !data.effectiveIsOnAC || data.isSupplementalDischarge {
            return (updateDischargeEMA(for: data), nil)
        }

        reset()
        return (nil, nil)
    }

    private mutating func updateDischargeEMA(for data: PowerData) -> Double? {
        switchMode(.discharging)
        let instant = instantDischargePowerW(for: data)
        guard instant >= 0.2 else { return dischargeEMA }
        dischargeEMA = ema(previous: dischargeEMA, sample: instant)
        return dischargeEMA
    }

    private mutating func updateChargeEMA(for data: PowerData) -> Double? {
        switchMode(.charging)
        let instant = data.batteryChargeRateW
        guard instant >= 0.2 else { return chargeEMA }
        let smoothed = ema(previous: chargeEMA, sample: instant)
        chargeEMA = smoothed
        return applyChargeTaper(
            rateW: smoothed,
            stateOfCharge: data.stateOfCharge ?? data.batteryPercent,
            targetSoc: data.chargeLimitPercent
        )
    }

    private mutating func switchMode(_ mode: Mode) {
        if lastMode != mode {
            dischargeEMA = nil
            chargeEMA = nil
            lastMode = mode
        }
    }

    private func instantDischargePowerW(for data: PowerData) -> Double {
        if data.isSupplementalDischarge {
            return max(data.batterySupplementalW, data.systemPowerW)
        }
        return data.systemPowerW
    }

    private func ema(previous: Double?, sample: Double) -> Double {
        guard let previous else { return sample }
        return previous + emaAlpha * (sample - previous)
    }

    /// Reduce effective charge rate near the charge target to approximate constant-voltage taper.
    private func applyChargeTaper(rateW: Double, stateOfCharge: Int, targetSoc: Int) -> Double {
        let clampedTarget = min(max(targetSoc, 1), 100)
        let taperStart = max(65, clampedTarget - 15)
        guard stateOfCharge > taperStart, clampedTarget > taperStart else { return rateW }
        let span = Double(clampedTarget - taperStart)
        let taper = max(0.25, 1.0 - Double(stateOfCharge - taperStart) / span * 0.75)
        return rateW * taper
    }
}
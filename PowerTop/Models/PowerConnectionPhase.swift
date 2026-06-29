import Foundation

/// User-visible connection phase driven by IOPS events and telemetry convergence.
enum PowerConnectionPhase: Equatable {
    case onBattery
    case connectingAC
    case onAC
}
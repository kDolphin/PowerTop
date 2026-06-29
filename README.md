# PowerTop

**English** | **[简体中文](README.zh-CN.md)**

A menu bar app that shows real-time power draw on Apple Silicon MacBooks. It reads raw telemetry from IOKit's `AppleSmartBattery` service, resolves actual power flow with cross-checks, and uses a connection-phase state machine to keep readings stable across plug/unplug events and stale data.

> **⚠️ MacBook only** — Requires a built-in battery. Mac mini, Mac Studio, and Mac Pro are not supported because they lack `AppleSmartBattery`.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## What PowerTop Shows

PowerTop gives you three surfaces for understanding instantaneous power:

| Surface | Purpose |
|---------|---------|
| **Menu bar** | Icon-only by default (`bolt.fill` on AC, `battery.50` on battery). Optionally shows live wattage (e.g. `19W` or `⚠ 33W`). |
| **Popover (280 px)** | Power-flow diagram, current system power, AC input vs battery contribution, charger specification and load, battery level + health, temperature, cycle count, and quick toggles. |
| **Detail window** | Full breakdown: power metrics with charging context, capacity and health numbers, per-cell voltages and balance, charger electricals, lifetime extremes (temp, voltage, current), device identifiers. |

All numbers come from the same IOKit property dictionary. No network calls, no third-party daemons.

## Why Accurate Power Numbers Are Difficult

macOS does not expose a single reliable "system is consuming X watts right now" value. Activity Monitor reports per-process energy impact, but the following situations are invisible or actively misleading without low-level telemetry:

- A small adapter (30 W) under heavy load: the battery silently supplies the difference.
- Plug or unplug events: `SystemPowerIn`, `IsCharging`, and `BatteryPower` can lag or retain values from the previous state for several seconds.
- Idle battery on AC: `BatteryPower` can be near zero or have ambiguous sign while `SystemLoad` remains valid.
- Flag vs. physics contradictions: `IsCharging` can be true while measured current shows discharge (and vice versa).

PowerTop exists to answer the actual question: **how is power moving between adapter, battery, and system at this moment?**

## Four Power Flow Scenarios

PowerTop classifies the machine into one of four physically distinct states.

| Scenario | Condition | Power Flow | Typical Header Value |
|----------|-----------|------------|----------------------|
| **Battery Powered** | `ExternalConnected = false` | Battery → System | System power |
| **AC Powered** | On AC, adapter meets or exceeds load, battery idle or not charging | AC → System | AC output ≈ system power |
| **AC Charging** | On AC, surplus input after system load | AC → System + Battery | System power (or AC input in menu bar) |
| **AC + Battery Supplement** | On AC, instantaneous load > adapter capability | AC → System<br>Battery → System (parallel) | System power, with warning indicator |

**Supplemental discharge** (the last case) is particularly important for MacBooks with 30–45 W adapters. The system power can legitimately exceed the adapter's rated wattage because the battery is discharging at the same time.

## Connection Phase State Machine

IOKit telemetry is not instantaneous on power-source edges. PowerTop therefore maintains an explicit three-phase machine on top of `ExternalConnected`:

```
onBattery  ──ExternalConnected rises──▶  connectingAC  ──converged or 3 s timeout──▶  onAC
     ▲                                                                       │
     └──────────────────── ExternalConnected falls ◀─────────────────────────┘
```

- **onBattery**: Any unplug immediately forces battery mode. Stale `SystemPowerIn` and `IsCharging` are ignored.
- **connectingAC**: Shown after a plug event. The UI stays in this phase until either physical signals (`BatteryPower` sign, non-zero charging current, or energy balance `acInputW >= systemPowerW`) confirm the new state, or a 3-second timeout elapses.
- **onAC**: Normal stable operation. The four scenarios above are evaluated normally.

This prevents the common UI bug where a freshly plugged machine still shows old AC input numbers or claims it is charging when it is actually still on battery.

## How Readings Are Computed

Primary data source: `PowerTelemetryData` inside `AppleSmartBattery` (keys: `SystemLoad`, `SystemPowerIn`, `BatteryPower`, plus voltage/current pairs).

1. **Flow resolution** (`resolveBatteryFlow`): decides charging / discharging / idle by preferring signed power values and energy balance (`acInputW` vs `systemLoadW`) over the `IsCharging` boolean.
2. **Metric computation** (`computePowerMetrics`): derives consistent `systemPowerW` and `batteryPowerW` for each of the four scenarios, with multiple fallbacks.
3. **Phase advancement**: the state machine above is driven by `ExternalConnected` edge events (via IOPS notifications) plus timer-based convergence checks.

Fallback path (rare): when `PowerTelemetryData` is absent, PowerTop falls back to `Amperage × Voltage / 1 000 000`. The UI then shows "Estimation Mode".

Sign conventions (important):
- `BatteryPower` and `Amperage` > 0 ⇒ discharge (battery supplying power)
- `BatteryPower` and `Amperage` < 0 ⇒ charge (battery consuming power)
- `ExternalConnected` is the authoritative physical presence of AC; all other fields can be stale.

## Menu Bar Wattage

Disabled by default. Enable "Show Power in Menu Bar" in the popover.

Behavior:
- Battery powered, AC powered, or supplemental discharge → shows system power
- AC charging → shows total AC input (the value the adapter is actually delivering)
- Values are rounded and capped at 99 W. `⚠` prefix appears for supplemental discharge or when the cap is hit.

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon MacBook with built-in battery

## Installation

### From Release

1. Download `PowerTop.zip` from [Releases](https://github.com/kDolphin/PowerTop/releases)
2. Unzip and move `PowerTop.app` to `/Applications`
3. First launch: right-click → Open (the app is unsigned)

### From Source

```bash
git clone https://github.com/kDolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

`build.sh` compiles with the Xcode SDK when available and produces both the `.app` and a distributable `.zip`.

## UI Implementation Notes

- Popover uses `ZStack` + `PreferenceKey` to measure intrinsic height and avoid empty space or clipped content on state transitions.
- Menu bar label forces redraw via an incrementing `uiRefreshToken` because SwiftUI does not always observe changes inside `MenuBarExtra` label views after sleep/wake.
- Detail window uses flat card sections (no disclosure groups) for immediate visibility of all available data.
- All strings are localized via `Localizable.strings`; the app follows system language.

## Telemetry Fields (Reference)

Core fields used from `AppleSmartBattery`:

| Field / Sub-dictionary | Meaning |
|------------------------|---------|
| `PowerTelemetryData.SystemLoad` | Total system consumption (mW) |
| `PowerTelemetryData.SystemPowerIn` | DC power delivered by the adapter (mW) |
| `PowerTelemetryData.BatteryPower` | Battery power with discharge positive (mW) |
| `ExternalConnected` | Physical AC presence (boolean, drives phase machine) |
| `IsCharging` / `FullyCharged` | Charge flags (used only as hints) |
| `AdapterDetails.Watts` | Adapter rating |
| `BatteryData.CellVoltage[]` | Individual cell voltages (mV) |
| `BatteryData.LifetimeData.*` | Historical min/max/avg temperature, voltage, current |
| `ChargerData.NotChargingReason` | Bitmask explaining why charging is inhibited |

Many additional fields (Qmax, design capacity, cycle counts, serial, etc.) are surfaced only in the detail window.

## Version History

### v1.2.0
- Redesigned detail window (merged power + charging context, flat layout)
- `SystemLoad` fallback fixes 0 W on idle battery
- Cell voltage spread summary
- Monitoring starts at launch; improved sleep/wake refresh

### v1.1.9
- Stale `SystemPowerIn` no longer bypasses "AC Connecting"
- Robust sleep/wake handling and coalesced refresh after power events
- No-battery hardware handling and inline login-item error display

### v1.1.8
- 280 px popover with dynamic height
- More reliable battery mode after unplug

See the full [release history](https://github.com/kDolphin/PowerTop/releases).

## Localization

Follows system language. You can override per-app in **System Settings → General → Language & Region → Applications**.

## License

MIT. See [LICENSE](LICENSE).

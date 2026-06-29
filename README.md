# PowerTop

**English** | **[简体中文](README.zh-CN.md)**

A menu bar app for real-time power monitoring on Apple Silicon MacBooks. It reads `PowerTelemetryData` from IOKit's `AppleSmartBattery` service, layers an event-driven connection-phase state machine on top, and produces consistent power-flow readings across plug/unplug edges, stale telemetry, and supplemental discharge.

> **⚠️ MacBook only** — Requires a built-in battery. Mac mini, Mac Studio, and Mac Pro lack `AppleSmartBattery` and are not supported.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## Motivation

macOS does not surface a single "how many watts is the system drawing right now" reading. Activity Monitor shows per-process energy, but not:

- When a 30 W adapter is plugged in under peak load, how do AC and battery supply the system in parallel?
- After unplugging, can stale `SystemPowerIn` make the UI still look like it's on AC?
- When the battery is idle and `BatteryPower` signs are ambiguous, does system power falsely read 0 W?

PowerTop addresses these with raw IOKit telemetry, physical power-flow cross-checks, and a connection-phase state machine — rendered in the menu bar and a detail window.

## Architecture

```
IOKit AppleSmartBattery
        │
        ▼
  readPowerData()          ← PowerTelemetryData + cell/health/lifetime fields
        │
        ▼
  resolveBatteryFlow()     ← charge/discharge polarity, energy balance, stale IsCharging
        │
        ▼
  computePowerMetrics()    ← system/AC/battery watts per operating mode
        │
        ▼
  Connection-phase FSM     ← ExternalConnected edges + 3 s convergence timeout
        │
        ▼
  PowerMonitor (@Observable) → Popover / detail window / menu bar label
```

| Component | Role |
|---|---|
| `AppDelegate` | Calls `monitor.start()` at `applicationDidFinishLaunching`; `stop()` on quit; `refreshNow()` on wake |
| `PowerMonitor` | 2 s polling + IOPS power-source notifications; pauses timer during sleep |
| `PowerData` | Display snapshot: power metrics, connection phase, health/cell/lifetime fields |
| `MenuBarLabelView` | Observes `monitor` directly; `uiRefreshToken` + `.id()` forces menu bar redraw |

Primary data path: `PowerTelemetryData` dictionary; falls back to legacy fields (`Amperage` × `Voltage`, etc.) when missing.

## UI & Data Surfaces

| Surface | Content |
|---|---|
| **Menu bar icon** | Default icon only: `bolt.fill` on AC, `battery.50` on battery; `exclamationmark.triangle` when no battery hardware |
| **Popover (280 px)** | Power-flow diagram, instant metrics, adapter load rate, not-charging reason, bottom toggles and shortcuts |
| **Detail window** | Current power (with charging context), battery health, cell voltage spread, charging details, lifetime stats, device info; empty sections hidden |
| **Menu bar wattage** | **Off by default**; enable "Show Power in Menu Bar" at the bottom of the popover for labels like `19W` |

The popover uses `ZStack` + `PreferenceKey` for intrinsic height measurement to avoid blank space on state changes. The detail window uses flat cards with no disclosure groups.

## Telemetry Fields

`readPowerData()` reads from `AppleSmartBattery`. Core `PowerTelemetryData` keys:

| IOKit property | Units / meaning |
|---|---|
| `SystemLoad` | mW → total system power |
| `SystemPowerIn` | mW → DC input from AC adapter |
| `BatteryPower` | mW → battery power (discharge positive, charge negative; cross-checked) |
| `Amperage` × `Voltage` | Signed battery power; `Amperage × Voltage / 1,000,000` |
| `ExternalConnected` | AC physically connected; edge events drive connection phase |
| `IsCharging` / `FullyCharged` | Charge flags; physical flow wins when flags disagree with amperage |
| `AdapterDetails` | Rated wattage, description, etc. |

The detail window also surfaces cell voltage arrays, Qmax, cycle/design capacity, temperature, and lifetime extremes — all from the same IOKit property bundle, no third-party SDK.

## Four Operating Modes

| Mode | Condition | Power flow |
|---|---|---|
| **Battery powered** | `ExternalConnected = false` | Battery → System |
| **AC powered** | On AC, adapter meets load, not charging | AC → System |
| **AC charging** | On AC, surplus input available | AC → System + Battery |
| **AC + battery supplement** | On AC, peak load exceeds adapter output | AC → System, Battery → System (parallel) |

Supplemental discharge: `isOnAC && batteryPowerW > 0` (battery discharging) while not in pure battery-powered phase.

## Connection-Phase State Machine

IOKit telemetry lags on plug/unplug edges. PowerTop layers three phases on `PowerConnectionPhase`:

| Phase | Trigger | UI behavior |
|---|---|---|
| **On battery** | Falling edge of `ExternalConnected` | Immediate battery mode; stale `SystemPowerIn` / `IsCharging` ignored |
| **AC connecting** | Rising edge of `ExternalConnected` | "AC Connecting" until `SystemPowerIn` or charging signals converge |
| **On AC** | Telemetry converged or 3 s timeout | One of the four operating modes above |

On plug-in, non-zero `SystemPowerIn` lingering from a prior AC session no longer skips "AC Connecting" without `hasResolvedACStateDuringConnecting` corroboration.

## Power Calculation Notes

- **AC charging**: System power ≈ `SystemPowerIn` − charge rate
- **On battery**: System power ≈ `BatteryPower` (discharge = consumption); falls back to `SystemLoad` when idle and signs are ambiguous
- **Supplemental discharge**: System power ≈ `SystemLoad`; battery contribution from signed `Amperage` / `BatteryPower`
- **Charge/discharge rate**: `Amperage × Voltage / 1,000,000`, cross-checked against `BatteryPower`
- **Unplug**: `ExternalConnected = false` overrides all stale flags
- **Plug-in**: Trust `ExternalConnected = true` immediately; estimate until `SystemPowerIn` updates

## Menu Bar Power Display

Icon only by default. After enabling "Show Power in Menu Bar" at the bottom of the popover:

| Mode | Shows | Label |
|---|---|---|
| Battery powered | System power | `19W` |
| AC charging | Total AC input | `31W` |
| AC + battery supplement | System power | `⚠ 33W` |
| AC powered | System power | `19W` |

- Values rounded; capped at `99W` above 99 W
- macOS menu bar text is system-monochrome; warnings use a `⚠` prefix (supplemental discharge, or >99 W otherwise)
- Preference stored in `UserDefaults` (`showPowerInMenuBar`)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon **MacBook** (built-in battery)

## Installation

### Download

Get `PowerTop.zip` from [Releases](https://github.com/kDolphin/PowerTop/releases):

1. Unzip
2. Move `PowerTop.app` to `/Applications`
3. First launch: right-click → **Open** (unsigned app)

### Build from Source

```bash
git clone https://github.com/kdolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

`build.sh` requires Xcode or a matching Swift toolchain. Outputs `build/PowerTop.app` and `build/PowerTop.zip`.

## Tech Stack

- **Swift 5** + **SwiftUI** (`MenuBarExtra`, standalone `Window` scene)
- **Observation** (`@Observable` `PowerMonitor`)
- **IOKit** / **IOKit.ps** (`AppleSmartBattery`, IOPS notifications)
- **ServiceManagement** (`SMAppService` login item)
- Localization: English + Simplified Chinese (`Localizable.strings`, follows system language)

## What's New

### v1.2.0

- Redesigned detail window: merged current power and charging context; labels aligned with popover
- Flat layout, no disclosure groups; removed blue focus ring on first open
- Monitoring starts at launch; `uiRefreshToken` fixes menu bar stale reads after sleep/wake
- `SystemLoad` fallback on battery idle fixes 0 W
- Cell voltage spread summary

### v1.1.9

- Plug-in stale telemetry: lingering `SystemPowerIn` no longer skips "AC Connecting"
- Block-based sleep/wake observers; timer invalidates before reschedule
- No-battery hardware banner and menu bar warning; inline login-item error

### v1.1.8

- Popover fills 280 px width; ZStack + PreferenceKey dynamic height
- Reliable battery mode after unplug; improved `ExternalConnected` tracking

[Older releases →](https://github.com/kDolphin/PowerTop/releases)

## Screenshots

*Menu bar popover: AC charging state with power-flow diagram*

*Detail window: battery health, cell data, and power parameters*

## Localization

Follows system language; override in **System Settings → General → Language & Region → Applications**.

## License

MIT. See [LICENSE](LICENSE).
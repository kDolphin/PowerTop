# PowerTop

**English** | **[简体中文](README.zh-CN.md)**

A native macOS menu bar app for real-time power monitoring on Apple Silicon MacBooks.

> **⚠️ MacBook only** — PowerTop requires a built-in battery. Mac mini, Mac Studio, and Mac Pro are not supported.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## Features

- **Real-time Power Flow Diagram** — Visualize how power flows between AC adapter, battery, and system
- **Supplemental Discharge Detection** — When the adapter cannot meet peak load, shows AC and battery supplying the system in parallel
- **Menu Bar Power Display** — Optional live wattage in the menu bar, with scenario-aware values and warning indicators
- **Instant AC Plug/Unplug Response** — Event-driven state machine switches to battery or AC connecting immediately when the charger is removed or attached
- **Instant Power Metrics** — System power consumption, AC adapter output, battery charge/discharge rate
- **Battery Health** — Health percentage, cycle count, design capacity, temperature
- **Detailed Parameters** — Deep dive into battery cell data, charging details, lifetime statistics
- **Power Source Notifications** — Instant UI refresh when AC is plugged/unplugged
- **Bilingual Support** — English & Chinese (Simplified), follows system language
- **Launch at Login** — Option to start automatically on login
- **Native macOS Experience** — Built with SwiftUI, menu bar app with no dock icon

## What's New

### v1.2.0

- **Redesigned detail window** — Merged power and charging into a contextual "Current Power" section; labels aligned with the popover; user-friendly copy instead of internal telemetry jargon
- **Flat detail layout** — All sections expanded by default (no disclosure groups); removed the blue focus ring on first open
- **Instant menu bar updates** — Power monitoring starts at launch; menu bar label refreshes immediately on wake without needing a click
- **0 W fix** — Battery-powered idle state now falls back to `SystemLoad` when battery telemetry signs are ambiguous
- **Cell balance summary** — Detail view shows per-cell voltage spread with a plain-language status

### v1.1.9

- **Plug-in stale telemetry fix** — "AC Connecting" no longer skipped when stale `SystemPowerIn` lingers from a previous session
- **Sleep/wake reliability** — Block-based workspace observers; timer stops during sleep and resumes on wake
- **Timer & IOPS robustness** — Timer invalidates before reschedule; coalesced plug/unplug refreshes
- **Unsupported hardware UX** — Banner and menu bar warning when no built-in battery is detected
- **Launch at Login feedback** — Inline error when registration fails

### v1.1.8

- **Fixed popover right-side blank** — Content fills the full 280px width
- **Improved dynamic popover sizing** — Reliable intrinsic height measurement via ZStack + PreferenceKey
- **State machine correctness fixes** — Unplug reliably stays on battery; better `ExternalConnected` tracking

[Older releases →](https://github.com/kDolphin/PowerTop/releases)

## Screenshots

*Menu bar popover showing AC charging state with power flow diagram*

*Detail window with comprehensive battery and power parameters*

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon **MacBook** (battery required — Mac mini / Mac Studio / Mac Pro not supported)

## Installation

### Download

Download the latest release from the [Releases page](https://github.com/kDolphin/PowerTop/releases).

1. Unzip `PowerTop.zip`
2. Move `PowerTop.app` to `/Applications`
3. On first launch, right-click the app and select **Open** (required for unsigned apps)

### Build from Source

```bash
git clone https://github.com/kdolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

`build.sh` requires Xcode (recommended) or a matching Swift SDK/toolchain. On success it outputs:

- `build/PowerTop.app` — runnable app bundle
- `build/PowerTop.zip` — zip archive ready for distribution

## How It Works

PowerTop reads power data from macOS IOKit's `AppleSmartBattery` service, specifically the `PowerTelemetryData` dictionary which provides:

| IOKit Property | Description |
|---|---|
| `SystemLoad` | Total system power consumption |
| `SystemPowerIn` | DC power from AC adapter |
| `BatteryPower` | Battery charge/discharge power |
| `Amperage` × `Voltage` | Signed battery power flow (negative = charging, positive = discharging) |
| `ExternalConnected` | Whether the AC adapter is physically connected |

### Connection State Machine

PowerTop layers an event-driven state machine on top of IOKit telemetry:

| Phase | Trigger | UI |
|---|---|---|
| **On battery** | Unplug detected (`ExternalConnected=false`) | Battery discharge — immediate, ignores stale AC telemetry |
| **AC connecting** | Plug detected (`ExternalConnected=true`) | "AC Connecting" until `SystemPowerIn` or charging signals arrive |
| **On AC** | Telemetry converged or 3 s timeout | Normal AC charging / powered / supplemental discharge |

### Power States

PowerTop recognizes four operating modes:

| Mode | Condition | Power Flow |
|---|---|---|
| **Battery powered** | Unplugged | Battery → System |
| **AC powered** | Plugged in, adapter meets load, not charging | AC → System |
| **AC charging** | Plugged in, surplus AC available | AC → System + Battery |
| **AC + battery supplement** | Plugged in, adapter under peak load | AC → System, Battery → System |

### Menu Bar Power Display

When enabled, the menu bar shows a rounded wattage label (e.g. `19W`). Values above 99 W are capped at `99W`. macOS menu bar text uses a single system color, so warnings are shown with a `⚠` prefix instead of red or orange text.

| Mode | Menu Bar Shows | Label |
|---|---|---|
| **Battery powered** | System power | `19W` |
| **AC charging** | Total AC input | `31W` |
| **AC + battery supplement** | System power | `⚠ 33W` — battery still discharging despite AC |
| **AC powered** | System power | `19W` |

**Warning rules**

- **`⚠` prefix** — Supplemental discharge: AC is connected but the battery is still supplying power
- **`⚠` prefix** — Power exceeds 99 W in any non-supplemental state (label still shows `99W`)
- **No prefix** — All other cases

### Power Calculation Logic

- **On AC charging**: System power = `SystemPowerIn` - charge rate (AC input minus what goes to battery)
- **On battery**: System power = `BatteryPower` (discharge rate = system consumption)
- **On supplemental discharge**: System power = `SystemLoad`; battery contribution = discharge rate from signed `Amperage` / `BatteryPower`
- **Charge/discharge rate**: Derived from signed `Amperage × Voltage / 1,000,000`, cross-checked against `BatteryPower` telemetry
- **Unplug**: `ExternalConnected=false` takes priority — stale `SystemPowerIn` and `IsCharging` are ignored
- **Plug-in**: `ExternalConnected=true` is trusted immediately; wattage estimates until `SystemPowerIn` updates
- **Stale flag handling**: When `IsCharging` disagrees with amperage polarity or energy balance, the physical power flow signals take priority

## Localization

PowerTop supports English and Simplified Chinese, automatically following your system language. You can also override the language in **System Settings → General → Language & Region → Applications**.

## License

MIT License. See [LICENSE](LICENSE) for details.
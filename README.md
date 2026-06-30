# PowerTop

**English** | **[简体中文](README.zh-CN.md)**

A clean, lightweight menu bar app that shows you exactly how much power your MacBook is using.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.3.2-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

> **MacBook only** — Requires a Mac with a built-in battery (Apple Silicon MacBook).

## Finally Know How Much Power You're Using

macOS never tells you the actual watts your MacBook is consuming right now. PowerTop changes that.

It gives you clear, real-time power information directly in the menu bar and a simple popover — so you can see exactly what's happening with power on your machine.

## Key Features

- **Optional menu bar wattage** — Show live power like `23W` right in the menu bar when you want it.
- **Power flow diagram** — See at a glance whether power is coming from the charger, the battery, or both at the same time.
- **Instant power numbers** — System power, charger output, and battery charge or discharge rate.
- **Charger load** — Know your adapter's wattage and how much of it is being used.
- **Battery overview** — Quick view of battery level, health, temperature, and cycle count.
- **Estimated battery time** — Time to empty or full in the popover and detail view when macOS no longer provides it.
- **Detailed information** — Auto-detected cell topology (e.g. 3S2P), series-group voltage, parallel cell currents, charging status, and lifetime stats.

Everything updates live and stays accurate even when you plug in or unplug your charger.

## Why People Use PowerTop

- Curious about real power consumption on their MacBook
- Want to know if their charger is powerful enough during heavy work
- Like seeing when the battery is helping supply power
- Want a simple, beautiful way to monitor battery health and charging behavior

It's a small, native app that does one thing well — no bloat, no subscriptions.

## Installation

### Download (Recommended)

Download the latest `PowerTop.zip` from the [Releases](https://github.com/kDolphin/PowerTop/releases) page:

1. Unzip the file
2. Drag `PowerTop.app` into your `/Applications` folder
3. First launch: right-click the app → **Open** (the app is not signed)

### Build from Source

```bash
git clone https://github.com/kDolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

## Requirements

- Apple Silicon MacBook (M-series)
- macOS 14 (Sonoma) or later

## How to Use

1. Open PowerTop — the icon appears in your menu bar.
2. Click the icon to open the popover with the power flow diagram and current readings.
3. Turn on **Show Power in Menu Bar** at the bottom if you want the wattage always visible.
4. Click **Details** for a full breakdown of power and battery information.

## Screenshots

### Popover

| **AC Powered** | **Battery Discharging** |
|----------------|--------------------------|
| <a href="screenshot/popover-ac-powered.png" target="_blank"><img src="screenshot/popover-ac-powered.png" width="260" alt="AC Powered"></a> | <a href="screenshot/popover-battery-discharging.png" target="_blank"><img src="screenshot/popover-battery-discharging.png" width="260" alt="Battery Discharging"></a> |

| **AC Charging** | **AC + Battery Supplement** |
|-----------------|------------------------------|
| <a href="screenshot/popover-ac-charging.png" target="_blank"><img src="screenshot/popover-ac-charging.png" width="260" alt="AC Charging"></a> | <a href="screenshot/popover-ac-supplement.png" target="_blank"><img src="screenshot/popover-ac-supplement.png" width="260" alt="AC + Battery Supplement"></a> |

### Detail Window

<a href="screenshot/detail-window.png" target="_blank"><img src="screenshot/detail-window.png" width="420" alt="PowerTop Details"></a>

## What's New

### v1.3.2

- **Battery health fix** — Reads design capacity, full charge, and health % from `BatteryData` on Apple Silicon; reorganized detail view with aligned overview bars and clearer capacity labels
- **Compact detail window** — Fixed 460pt width for a tighter layout

### v1.3.1

- **Adaptive cell topology** — Detects each MacBook's actual S×P layout from IOKit (e.g. 2S2P on Air, 3S2P on Pro); no hardcoded topology

### v1.3.0

- **Estimated battery time** — Computes time to empty or full from remaining energy and smoothed power when macOS stops reporting `AvgTimeToEmpty` / `AvgTimeToFull`; shown in popover and detail view
- **Cell data fix (Apple Silicon)** — Reads per-series-group voltage/Qmax and per-parallel-cell current from IOKit bank/cell nodes; topology is detected per machine
- **Clearer cell balance** — Separate series voltage balance and parallel current balance
- **Detail window polish** — Fixed duplicate rows, moved manufacture date to device info, improved labels

### v1.2.0

- Redesigned detail window, flat layout, instant menu bar updates after wake, 0 W idle fix, cell balance summary

[Older releases →](https://github.com/kDolphin/PowerTop/releases)

## License

MIT License. See [LICENSE](LICENSE) for details.

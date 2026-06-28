# PowerTop

A native macOS menu bar app for real-time power monitoring on Apple Silicon MacBooks.

> **⚠️ MacBook only** — PowerTop requires a built-in battery. Mac mini, Mac Studio, and Mac Pro are not supported.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## Features

- **Real-time Power Flow Diagram** — Visualize how power flows between AC adapter, battery, and system
- **Instant Power Metrics** — System power consumption, AC adapter output, battery charge/discharge rate
- **Battery Health** — Health percentage, cycle count, design capacity, temperature
- **Detailed Parameters** — Deep dive into battery cell data, charging details, lifetime statistics
- **Power Source Notifications** — Instant UI refresh when AC is plugged/unplugged
- **Bilingual Support** — English & Chinese (Simplified), follows system language
- **Launch at Login** — Option to start automatically on login
- **Native macOS Experience** — Built with SwiftUI, menu bar app with no dock icon

## Screenshots

<p align="center">
  <img src="docs/images/powertop-menu.webp" alt="PowerTop menu bar popover" width="34%" />
  &nbsp;&nbsp;
  <img src="docs/images/powertop-details.webp" alt="PowerTop detail window" width="59%" />
</p>

<p align="center">
  <sub>Menu bar power overview · Detailed battery and power parameters</sub>
</p>

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon **MacBook** (battery required — Mac mini / Mac Studio / Mac Pro not supported)

## Installation

### Download

Download the latest release from the [Releases page](https://github.com/kdolphin/PowerTop/releases).

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

## How It Works

PowerTop reads power data from macOS IOKit's `AppleSmartBattery` service, specifically the `PowerTelemetryData` dictionary which provides:

| IOKit Property | Description |
|---|---|
| `SystemLoad` | Total system power consumption |
| `SystemPowerIn` | DC power from AC adapter |
| `BatteryPower` | Battery charge/discharge power |
| `Amperage` × `Voltage` | Actual battery charge rate (more reliable than BatteryPower) |

### Power Calculation Logic

- **On AC charging**: System power = `SystemPowerIn` - charge rate (AC input minus what goes to battery)
- **On battery**: System power = `BatteryPower` (discharge rate = system consumption)
- **Charge rate**: Calculated from `abs(Amperage) × Voltage / 1,000,000` for accuracy

## Localization

PowerTop supports English and Simplified Chinese, automatically following your system language. You can also override the language in **System Settings → General → Language & Region → Applications**.

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## 中文说明

一个原生 macOS 菜单栏应用，用于 Apple Silicon MacBook 的实时功耗监控。

> **⚠️ 仅支持 MacBook** — PowerTop 需要内置电池。Mac mini、Mac Studio、Mac Pro 不受支持。

### 功能特性

- **实时功率流向图** — 可视化 AC 适配器、电池和系统之间的功率流向
- **瞬时功率指标** — 系统功耗、AC 适配器输出、电池充放电功率
- **电池健康** — 健康度百分比、循环次数、设计容量、温度
- **详细参数** — 电芯数据、充电详情、生命周期统计
- **电源变更通知** — 插拔电源即时刷新界面
- **双语支持** — 中文和英文，跟随系统语言
- **开机启动** — 可选登录时自动启动
- **原生 macOS 体验** — SwiftUI 构建，菜单栏应用，无 Dock 图标

### 安装

从 [Releases 页面](https://github.com/kdolphin/PowerTop/releases) 下载最新版本。

1. 解压 `PowerTop.zip`
2. 将 `PowerTop.app` 移动到 `/Applications`
3. 首次启动时，右键点击应用选择**打开**（未签名应用需要此操作）

### 从源码构建

```bash
git clone https://github.com/kdolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

### 功率计算逻辑

- **AC 充电时**：系统功耗 = `SystemPowerIn` - 充电功率（AC 输入减去向电池供电的部分）
- **电池供电时**：系统功耗 = `BatteryPower`（放电功率 = 系统消耗）
- **充电功率**：使用 `abs(Amperage) × Voltage / 1,000,000` 计算，比 BatteryPower 更准确

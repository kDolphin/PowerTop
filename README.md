# PowerTop

A native macOS menu bar app for real-time power monitoring on Apple Silicon MacBooks.

> **⚠️ MacBook only** — PowerTop requires a built-in battery. Mac mini, Mac Studio, and Mac Pro are not supported.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.1.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## Features

- **Real-time Power Flow Diagram** — Visualize how power flows between AC adapter, battery, and system
- **Supplemental Discharge Detection** — When the adapter cannot meet peak load, shows AC and battery supplying the system in parallel
- **Instant Power Metrics** — System power consumption, AC adapter output, battery charge/discharge rate
- **Battery Health** — Health percentage, cycle count, design capacity, temperature
- **Detailed Parameters** — Deep dive into battery cell data, charging details, lifetime statistics
- **Power Source Notifications** — Instant UI refresh when AC is plugged/unplugged
- **Bilingual Support** — English & Chinese (Simplified), follows system language
- **Launch at Login** — Option to start automatically on login
- **Native macOS Experience** — Built with SwiftUI, menu bar app with no dock icon

## What's New in v1.1.0

- **Smarter power state detection** — Cross-checks `IsCharging` with signed `Amperage` and `BatteryPower` to avoid misreading supplemental discharge as charging when IOKit flags are stale
- **Dual-source flow diagram** — Supplemental discharge now shows AC and battery as parallel sources feeding the system
- **New power source label** — Displays "AC + Battery Supplement" when the battery fills the gap left by an underpowered adapter
- **Version label** — Shows `v1.1.0` in the popover footer

## Screenshots

*Menu bar popover showing AC charging state with power flow diagram*

*Detail window with comprehensive battery and power parameters*

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

### Power States

PowerTop recognizes four operating modes:

| Mode | Condition | Power Flow |
|---|---|---|
| **Battery powered** | Unplugged | Battery → System |
| **AC powered** | Plugged in, adapter meets load, not charging | AC → System |
| **AC charging** | Plugged in, surplus AC available | AC → System + Battery |
| **AC + battery supplement** | Plugged in, adapter under peak load | AC → System, Battery → System |

### Power Calculation Logic

- **On AC charging**: System power = `SystemPowerIn` - charge rate (AC input minus what goes to battery)
- **On battery**: System power = `BatteryPower` (discharge rate = system consumption)
- **On supplemental discharge**: System power = `SystemLoad`; battery contribution = discharge rate from signed `Amperage` / `BatteryPower`
- **Charge/discharge rate**: Derived from signed `Amperage × Voltage / 1,000,000`, cross-checked against `BatteryPower` telemetry
- **Stale flag handling**: When `IsCharging` disagrees with amperage polarity, the physical power flow signals take priority

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
- **补充放电检测** — 适配器功率不足时，显示 AC 与电池并联向系统供电
- **瞬时功率指标** — 系统功耗、AC 适配器输出、电池充放电功率
- **电池健康** — 健康度百分比、循环次数、设计容量、温度
- **详细参数** — 电芯数据、充电详情、生命周期统计
- **电源变更通知** — 插拔电源即时刷新界面
- **双语支持** — 中文和英文，跟随系统语言
- **开机启动** — 可选登录时自动启动
- **原生 macOS 体验** — SwiftUI 构建，菜单栏应用，无 Dock 图标

### v1.1.0 更新内容

- **更准确的功率状态判定** — 交叉校验 `IsCharging` 与带符号的 `Amperage`、`BatteryPower`，避免 IOKit 标志滞后时将补充放电误判为充电
- **双源流向图** — 补充放电场景下，AC 与电池作为并联电源共同向系统供电
- **新增电源状态文案** — 适配器功率不足时显示「AC + 电池补充供电」
- **版本号显示** — Popover 底部显示 `v1.1.0`

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

`build.sh` 需要 Xcode（推荐）或版本匹配的 Swift SDK/工具链。构建成功后会生成：

- `build/PowerTop.app` — 可直接运行的应用
- `build/PowerTop.zip` — 可分发用的压缩包

### 功率状态

PowerTop 识别四种工作模式：

| 模式 | 条件 | 功率流向 |
|---|---|---|
| **电池供电** | 未插电源 | 电池 → 系统 |
| **AC 供电** | 插电源，适配器满足负载，未充电 | AC → 系统 |
| **AC 充电** | 插电源，AC 有剩余功率 | AC → 系统 + 电池 |
| **AC + 电池补充** | 插电源，适配器无法满足峰值负载 | AC → 系统，电池 → 系统 |

### 功率计算逻辑

- **AC 充电时**：系统功耗 = `SystemPowerIn` - 充电功率（AC 输入减去向电池供电的部分）
- **电池供电时**：系统功耗 = `BatteryPower`（放电功率 = 系统消耗）
- **补充放电时**：系统功耗 = `SystemLoad`；电池贡献功率来自带符号的 `Amperage` / `BatteryPower`
- **充放电功率**：由带符号的 `Amperage × Voltage / 1,000,000` 计算，并与 `BatteryPower` 遥测交叉验证
- **滞后标志处理**：当 `IsCharging` 与电流极性矛盾时，以实际功率流向信号为准

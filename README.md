# PowerTop

A native macOS menu bar app for real-time power monitoring on Apple Silicon MacBooks.

> **⚠️ MacBook only** — PowerTop requires a built-in battery. Mac mini, Mac Studio, and Mac Pro are not supported.

<p align="center">
  <img src="https://img.shields.io/badge/version-1.1.5-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## Features

- **Real-time Power Flow Diagram** — Visualize how power flows between AC adapter, battery, and system
- **Supplemental Discharge Detection** — When the adapter cannot meet peak load, shows AC and battery supplying the system in parallel
- **Menu Bar Power Display** — Optional live wattage in the menu bar, with scenario-aware values and color warnings
- **Instant Power Metrics** — System power consumption, AC adapter output, battery charge/discharge rate
- **Battery Health** — Health percentage, cycle count, design capacity, temperature
- **Detailed Parameters** — Deep dive into battery cell data, charging details, lifetime statistics
- **Power Source Notifications** — Instant UI refresh when AC is plugged/unplugged
- **Bilingual Support** — English & Chinese (Simplified), follows system language
- **Launch at Login** — Option to start automatically on login
- **Native macOS Experience** — Built with SwiftUI, menu bar app with no dock icon

## What's New in v1.1.5

- **Menu bar power display** — Toggle "Show Power in Menu Bar" in the popover footer to show live wattage next to the icon (off by default)
- **Scenario-aware wattage** — Menu bar value adapts to the current power state instead of always showing system load
- **Color warnings** — Red when AC is connected but the battery is still discharging (supplemental discharge); orange when power exceeds 99 W in other states
- **Grouped settings panel** — Launch at Login and menu bar options are grouped in a footer card, aligned with the Details button style
- **Stable popover layout** — Popover height no longer shifts when AC power state changes

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

### Menu Bar Power Display

When enabled, the menu bar shows a rounded wattage label (e.g. `19W`). Values above 99 W are capped at `99W`.

| Mode | Menu Bar Shows | Color |
|---|---|---|
| **Battery powered** | System power | Default |
| **AC charging** | Total AC input | Default |
| **AC + battery supplement** | System power | **Red** — battery still discharging despite AC |
| **AC powered** | System power | Default |

**Color rules**

- **Red** — Supplemental discharge: AC is connected but the battery is still supplying power. This reminds you the battery is draining even though the charger is plugged in.
- **Orange** — Power exceeds 99 W in any non-supplemental state (label still shows `99W`).
- **Default** — All other cases.

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
- **菜单栏功率显示** — 可选择在菜单栏显示实时功率，按场景切换数值与颜色提醒
- **瞬时功率指标** — 系统功耗、AC 适配器输出、电池充放电功率
- **电池健康** — 健康度百分比、循环次数、设计容量、温度
- **详细参数** — 电芯数据、充电详情、生命周期统计
- **电源变更通知** — 插拔电源即时刷新界面
- **双语支持** — 中文和英文，跟随系统语言
- **开机启动** — 可选登录时自动启动
- **原生 macOS 体验** — SwiftUI 构建，菜单栏应用，无 Dock 图标

### v1.1.5 更新内容

- **菜单栏功率显示** — Popover 底部可开启「菜单栏显示功率」，在图标旁显示实时瓦数（默认关闭）
- **按场景显示数值** — 菜单栏功率随当前电源状态切换，不再固定显示系统功耗
- **颜色提醒** — 补充放电时显示红色（插着 AC 电池仍在放电）；其他场景超过 99 W 时显示橙色
- **设置项分组** — 「登录时启动」与菜单栏开关归入底部卡片，与「详细参数」按钮风格一致
- **Popover 布局稳定** — 切换 AC 电源状态时，Popover 高度不再跳动

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

### 菜单栏功率显示

开启后，菜单栏显示四舍五入的功率文字（如 `19W`）。实际功率超过 99 W 时，显示封顶为 `99W`。

| 模式 | 菜单栏显示 | 颜色 |
|---|---|---|
| **电池供电** | 系统功耗 | 默认 |
| **AC 充电** | AC 总输入 | 默认 |
| **AC + 电池补充** | 系统功耗 | **红色** — 插着 AC 电池仍在放电 |
| **AC 供电** | 系统功耗 | 默认 |

**颜色规则**

- **红色** — 补充放电：已连接 AC，但电池仍在向系统供电。提醒用户此时电池仍在消耗，不要以为插着电就安全。
- **橙色** — 非补充放电场景下，功率超过 99 W（文字仍显示 `99W`）。
- **默认** — 其余情况。

### 功率计算逻辑

- **AC 充电时**：系统功耗 = `SystemPowerIn` - 充电功率（AC 输入减去向电池供电的部分）
- **电池供电时**：系统功耗 = `BatteryPower`（放电功率 = 系统消耗）
- **补充放电时**：系统功耗 = `SystemLoad`；电池贡献功率来自带符号的 `Amperage` / `BatteryPower`
- **充放电功率**：由带符号的 `Amperage × Voltage / 1,000,000` 计算，并与 `BatteryPower` 遥测交叉验证
- **滞后标志处理**：当 `IsCharging` 与电流极性矛盾时，以实际功率流向信号为准
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

*Menu bar popover showing AC charging state with power flow diagram*

*Detail window with comprehensive battery and power parameters*

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon **MacBook** (battery required — Mac mini / Mac Studio / Mac Pro not supported)

## Installation

### Download

Download `PowerTop.dmg` from the [Releases page](https://github.com/kDolphin/PowerTop/releases).

1. Open `PowerTop.dmg` and drag **PowerTop** to the **Applications** folder.
2. In Finder, open **Applications** and launch **PowerTop** once. When macOS
   reports that it cannot verify the app, close the warning.
3. Open **System Settings → Privacy & Security** and scroll down to **Security**.
4. Next to the message that **PowerTop was blocked to protect your Mac**, click
   **Open Anyway**.
5. Authenticate with Touch ID or your password, then confirm **Open**. Future
   launches work normally.

PowerTop is ad-hoc signed but cannot be notarized because the project does not
have an Apple Developer account, so this one-time Gatekeeper approval is
expected. In the uncommon case that **Open Anyway** still does not work, run
this once after moving the app to `/Applications`:

```bash
xattr -cr /Applications/PowerTop.app
```

### Build from Source

```bash
git clone https://github.com/kDolphin/PowerTop.git
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

从 [Releases 页面](https://github.com/kDolphin/PowerTop/releases) 下载 `PowerTop.dmg`。

1. 打开 `PowerTop.dmg`，将 **PowerTop** 拖入 **Applications（应用程序）**。
2. 在 Finder 中打开“应用程序”，双击 **PowerTop** 启动一次。看到 macOS
   无法验证该 App 的提示后，关闭提示。
3. 打开**系统设置 → 隐私与安全性**，向下滚动到“安全性”。
4. 找到“已阻止‘PowerTop’以保护 Mac”，点击**仍要打开**。
5. 使用 Touch ID 或登录密码验证，然后确认**打开**。以后可以正常双击启动。

PowerTop 已进行 ad-hoc 签名，但因为项目没有 Apple Developer 账号而无法进行
Apple 公证，所以上述 Gatekeeper 放行操作首次启动时属于预期行为。极少数情况下
点击**仍要打开**后依然失败，请在应用已移入 `/Applications` 后执行一次：

```bash
xattr -cr /Applications/PowerTop.app
```

### 从源码构建

```bash
git clone https://github.com/kDolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

### 功率计算逻辑

- **AC 充电时**：系统功耗 = `SystemPowerIn` - 充电功率（AC 输入减去向电池供电的部分）
- **电池供电时**：系统功耗 = `BatteryPower`（放电功率 = 系统消耗）
- **充电功率**：使用 `abs(Amperage) × Voltage / 1,000,000` 计算，比 BatteryPower 更准确

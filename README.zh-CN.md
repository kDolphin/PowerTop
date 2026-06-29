# PowerTop

**[English](README.md)** | **简体中文**

一个为 Apple Silicon MacBook 设计的菜单栏实时功耗监控工具。它直接读取 IOKit `AppleSmartBattery` 服务的原始遥测数据，通过物理功率流向交叉校验和连接阶段状态机，在插拔电源、数据滞后、补充放电等边界情况下给出稳定、一致的功率读数。

> **⚠️ 仅支持 MacBook** — 需要内置电池。Mac mini、Mac Studio 和 Mac Pro 因缺少 `AppleSmartBattery` 服务，不受支持。

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## PowerTop 能看到什么

PowerTop 提供三个观察界面，用于理解系统瞬时功率：

| 界面 | 作用 |
|------|------|
| **菜单栏** | 默认仅图标（AC 时为 `bolt.fill`，电池时为 `battery.50`）。可选择显示实时功率（如 `19W` 或 `⚠ 33W`）。 |
| **弹出窗口（280 px）** | 功率流向图、当前系统功耗、AC 输入与电池贡献对比、充电器规格与负载率、电量与健康度、温度、循环次数，以及快速开关。 |
| **详细参数窗口** | 完整拆解：带充电上下文的功率指标、容量与健康数据、各电芯电压与均衡状态、充电器电气参数、生命周期极值（温度、电压、电流）、设备标识信息。 |

所有数值均来自同一份 IOKit 属性字典，无网络请求，不依赖第三方守护进程。

## 为什么准确的功率数字很难获得

macOS 没有提供一个在电源切换时依然可靠的「系统此刻消耗 X 瓦」的单一数值。活动监视器能给出进程能耗，但以下场景会让高层数据失真或缺失：

- 小功率适配器（30W）高负载时，电池会无声地并联补充供电。
- 插拔电源瞬间：`SystemPowerIn`、`IsCharging`、`BatteryPower` 可能保留上一状态的数据数秒。
- AC 上的电池空闲时：`BatteryPower` 可能接近零或符号模糊，而 `SystemLoad` 仍然有效。
- 标志位与物理量矛盾：`IsCharging` 为 true 时实测电流却在放电（反之亦然）。

PowerTop 的目标是回答真实问题：**此刻功率究竟在适配器、电池和系统之间如何流动？**

## 四种功率流动场景

PowerTop 将机器状态归为四种物理上不同的场景：

| 场景 | 条件 | 功率流向 | 典型头部数值 |
|------|------|----------|--------------|
| **电池供电** | `ExternalConnected = false` | 电池 → 系统 | 系统功耗 |
| **AC 供电** | 插 AC，适配器满足或超过负载，电池空闲或未充电 | AC → 系统 | AC 输出 ≈ 系统功耗 |
| **AC 充电** | 插 AC，输入在满足系统后仍有盈余 | AC → 系统 + 电池 | 系统功耗（菜单栏显示 AC 总输入） |
| **AC + 电池补充** | 插 AC，瞬时负载超过适配器能力 | AC → 系统<br>电池 → 系统（并联） | 系统功耗，带警告标识 |

**补充放电**（最后一种）对使用 30–45 W 适配器的 MacBook 尤为常见。系统功耗可以合法地超过适配器铭牌功率，因为电池同时在放电。

## 连接阶段状态机

IOKit 遥测在电源边沿事件上并不同步。PowerTop 因此在 `ExternalConnected` 之上维护一个明确的三阶段机：

```
onBattery  ──ExternalConnected 上升──▶  connectingAC  ──收敛或 3 秒超时──▶  onAC
     ▲                                                                      │
     └────────────────── ExternalConnected 下降 ◀───────────────────────────┘
```

- **onBattery（电池供电）**：任何拔掉动作立即强制进入电池模式。滞留的 `SystemPowerIn` 和 `IsCharging` 会被忽略。
- **connectingAC（AC 连接中）**：插上电源后显示此阶段。直到物理信号（`BatteryPower` 符号、非零充电电流、或能量平衡 `acInputW >= systemPowerW`）确认新状态，或 3 秒超时，才会离开。
- **onAC（AC 稳定）**：正常稳定运行，按上述四种场景正常计算。

这个机制避免了常见 UI 问题：刚插上电源的机器仍显示旧的 AC 输入数值，或错误声称正在充电而实际仍在用电池。

## 读数的计算方式

主数据源：`AppleSmartBattery` 中的 `PowerTelemetryData`（关键键：`SystemLoad`、`SystemPowerIn`、`BatteryPower`，以及电压/电流对）。

1. **流向解析**（`resolveBatteryFlow`）：优先使用带符号的功率值和能量平衡（`acInputW` 与 `systemLoadW` 比较），而非 `IsCharging` 布尔值，来判定充电 / 放电 / 空闲。
2. **功率指标计算**（`computePowerMetrics`）：为四种场景推导一致的 `systemPowerW` 和 `batteryPowerW`，并有多重回退。
3. **阶段推进**：状态机由 IOPS 通知驱动的 `ExternalConnected` 边沿事件，加上基于定时器的收敛检查共同控制。

回退路径（较少见）：当 `PowerTelemetryData` 不存在时，PowerTop 使用 `Amperage × Voltage / 1 000 000` 计算。此时界面会显示「估算模式」。

符号约定（重要）：
- `BatteryPower` 和 `Amperage` > 0 ⇒ 放电（电池对外供电）
- `BatteryPower` 和 `Amperage` < 0 ⇒ 充电（电池消耗功率）
- `ExternalConnected` 是 AC 物理存在的权威标志；其他字段都可能滞后。

## 菜单栏功率显示

默认关闭。在弹出窗口底部开启「菜单栏显示功率」。

显示规则：
- 电池供电、AC 供电、补充放电 → 显示系统功耗
- AC 充电 → 显示 AC 适配器总输入（适配器实际正在输出的功率）
- 数值四舍五入，超过 99 W 封顶为 99W。补充放电或触顶时使用 `⚠` 前缀。

## 系统要求

- macOS 14.0（Sonoma）或更高版本
- 配备内置电池的 Apple Silicon MacBook

## 安装方式

### 下载安装

1. 从 [Releases](https://github.com/kDolphin/PowerTop/releases) 下载 `PowerTop.zip`
2. 解压后将 `PowerTop.app` 移到 `/Applications`
3. 首次启动：右键 → 打开（应用未签名）

### 源码构建

```bash
git clone https://github.com/kDolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

`build.sh` 优先使用 Xcode SDK 编译，产物包括 `.app` 和可分发的 `.zip`。

## 界面实现要点

- Popover 使用 `ZStack` + `PreferenceKey` 测量内容固有高度，避免状态切换时出现空白或裁切。
- 菜单栏标签通过递增的 `uiRefreshToken` 强制重绘，因为 SwiftUI 在 `MenuBarExtra` 的 label 中对休眠唤醒后的变化有时不会自动响应。
- 详细参数窗口采用平铺卡片布局（无折叠组），所有可用数据一目了然。
- 所有文案通过 `Localizable.strings` 本地化，应用跟随系统语言。

## 遥测字段参考

从 `AppleSmartBattery` 中使用的主要字段：

| 字段 / 子字典 | 含义 |
|---------------|------|
| `PowerTelemetryData.SystemLoad` | 系统总功耗（mW） |
| `PowerTelemetryData.SystemPowerIn` | 适配器提供的直流功率（mW） |
| `PowerTelemetryData.BatteryPower` | 电池功率（放电为正，mW） |
| `ExternalConnected` | AC 物理存在（布尔值，驱动阶段机） |
| `IsCharging` / `FullyCharged` | 充电标志（仅作为辅助判断） |
| `AdapterDetails.Watts` | 适配器额定功率 |
| `BatteryData.CellVoltage[]` | 各电芯电压（mV） |
| `BatteryData.LifetimeData.*` | 历史最高/最低/平均温度、电压、电流 |
| `ChargerData.NotChargingReason` | 未充电原因位掩码 |

更多字段（Qmax、设计容量、循环次数、序列号等）仅在详细参数窗口中展示。

## 更新记录

### v1.2.0
- 详细参数窗口重设计（合并电源与充电上下文，平铺布局）
- `SystemLoad` 回退修复电池空闲时 0 W 问题
- 增加电芯压差摘要
- 启动即开始监控；改进休眠唤醒后的刷新

### v1.1.9
- 插电后残留 `SystemPowerIn` 不再绕过「AC 连接中」
- 更健壮的休眠/唤醒处理和电源事件后的合并刷新
- 无电池硬件提示与登录项失败的内联错误显示

### v1.1.8
- 280 px 弹出窗口 + 动态高度
- 拔掉电源后更可靠地停留在电池模式

完整历史见 [Releases](https://github.com/kDolphin/PowerTop/releases)。

## 本地化

跟随系统语言。可在 **系统设置 → 通用 → 语言与地区 → 应用程序** 中为 PowerTop 单独指定语言。

## 许可证

MIT。详见 [LICENSE](LICENSE)。

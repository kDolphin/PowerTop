# PowerTop

**[English](README.md)** | **简体中文**

Apple Silicon MacBook 的实时功耗监控菜单栏应用。从 IOKit `AppleSmartBattery` 的 `PowerTelemetryData` 读取遥测，叠加事件驱动连接阶段状态机，在插拔电源、遥测滞后、补充放电等边界条件下给出一致的功率流向与读数。

> **⚠️ 仅支持 MacBook** — 需要内置电池。Mac mini、Mac Studio、Mac Pro 无 `AppleSmartBattery` 服务，不受支持。

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## 动机

macOS 不直接暴露「系统此刻消耗多少瓦」这类读数。活动监视器可看进程能耗，但无法回答：

- 插着 30 W 适配器跑峰值负载时，AC 与电池如何并联供电？
- 拔掉电源后，滞后的 `SystemPowerIn` 会不会让界面仍显示在充电？
- 电池 idle 时 `BatteryPower` 符号不明确，系统功耗会不会误报 0 W？

PowerTop 针对这些问题：用 IOKit 原始遥测 + 物理功率流向交叉校验 + 连接阶段状态机，在菜单栏和详情窗口给出可解释的实时功率图。

## 架构

```
IOKit AppleSmartBattery
        │
        ▼
  readPowerData()          ← PowerTelemetryData + 电芯/健康/生命周期字段
        │
        ▼
  resolveBatteryFlow()     ← 充放电极性、能量平衡、IsCharging 矛盾处理
        │
        ▼
  computePowerMetrics()    ← 四种工作模式下的系统/AC/电池功率
        │
        ▼
  连接阶段状态机            ← ExternalConnected 边沿 + 3s 超时收敛
        │
        ▼
  PowerMonitor (@Observable) → Popover / 详情窗 / 菜单栏 Label
```

| 组件 | 职责 |
|---|---|
| `AppDelegate` | `applicationDidFinishLaunching` 即 `monitor.start()`；退出时 `stop()`；唤醒后 `refreshNow()` |
| `PowerMonitor` | 2 s 定时轮询 + IOPS 电源变更通知；休眠停表、唤醒恢复 |
| `PowerData` | 展示层快照：功率指标、连接阶段、健康/电芯/生命周期等 |
| `MenuBarLabelView` | 直接观察 `monitor`；`uiRefreshToken` + `.id()` 强制菜单栏重绘 |

数据源优先级：`PowerTelemetryData` 字典为主；缺失时回退 legacy 字段（`Amperage` × `Voltage` 等）。

## 界面与数据出口

| 出口 | 内容 |
|---|---|
| **菜单栏图标** | 默认仅图标：AC 为 `bolt.fill`，电池为 `battery.50`；无电池硬件时 `exclamationmark.triangle` |
| **Popover（280 px）** | 功率流向图、瞬时指标、充电器负载率、未充电原因、底部开关与快捷入口 |
| **详细参数窗口** | 当前电源（含充电上下文）、电池健康、电芯压差、充电详情、生命周期、设备信息；无数据分区自动隐藏 |
| **菜单栏功率文字** | **默认关闭**；在 Popover 底部开启「菜单栏显示功率」后显示 `19W` 等读数 |

Popover 用 `ZStack` + `PreferenceKey` 测量内在高度，避免状态切换后出现空白；详情窗为平铺卡片，无折叠组。

## 遥测字段

`readPowerData()` 从 `AppleSmartBattery` 读取，`PowerTelemetryData` 核心键：

| IOKit 属性 | 单位 / 含义 |
|---|---|
| `SystemLoad` | mW → 系统总功耗 |
| `SystemPowerIn` | mW → AC 适配器直流输入 |
| `BatteryPower` | mW → 电池功率（放电为正、充电为负，与遥测符号交叉校验） |
| `Amperage` × `Voltage` | 带符号电池功率；`Amperage × Voltage / 1,000,000` |
| `ExternalConnected` | AC 物理连接；边沿事件驱动连接阶段 |
| `IsCharging` / `FullyCharged` | 充电标志；与电流极性矛盾时以物理流向为准 |
| `AdapterDetails` | 额定功率、描述等 |

详情窗还展示电芯电压数组、Qmax、循环/设计容量、温度与生命周期极值等——均来自同一 IOKit 属性包，非第三方 SDK。

## 四种工作模式

| 模式 | 条件 | 功率流向 |
|---|---|---|
| **电池供电** | `ExternalConnected = false` | 电池 → 系统 |
| **AC 供电** | 插 AC，适配器满足负载，未充电 | AC → 系统 |
| **AC 充电** | 插 AC，输入有盈余 | AC → 系统 + 电池 |
| **AC + 电池补充** | 插 AC，峰值负载超过适配器输出 | AC → 系统，电池 → 系统（并联） |

补充放电判定：`isOnAC && batteryPowerW > 0`（电池在放电）且非纯电池供电阶段。

## 连接阶段状态机

IOKit 遥测在插拔瞬间会滞后。PowerTop 在 `PowerConnectionPhase` 上叠加三阶段机：

| 阶段 | 触发 | UI 行为 |
|---|---|---|
| **电池供电** | `ExternalConnected` 0→1 的反向边沿 | 立即切电池模式；清零/忽略滞后 `SystemPowerIn`、`IsCharging` |
| **AC 连接中** | `ExternalConnected` 1 边沿 | 显示「AC 连接中」；等待 `SystemPowerIn` 或充电信号收敛 |
| **AC 稳定** | 遥测收敛或 3 s 超时 | 进入上述四种工作模式之一 |

插上电源时，若上一段 AC 会话残留非零 `SystemPowerIn`，需 `hasResolvedACStateDuringConnecting` 佐证后才跳过「连接中」——避免误进稳定 AC 态。

## 功率计算要点

- **AC 充电**：系统功耗 ≈ `SystemPowerIn` − 充电功率
- **电池供电**：系统功耗 ≈ `BatteryPower`（放电即消耗）；idle 且符号不明时回退 `SystemLoad`
- **补充放电**：系统功耗 ≈ `SystemLoad`；电池贡献来自带符号 `Amperage` / `BatteryPower`
- **充放电率**：`Amperage × Voltage / 1,000,000`，与 `BatteryPower` 交叉验证
- **拔掉**：`ExternalConnected = false` 优先于一切滞后标志
- **插上**：立即信任 `ExternalConnected = true`；`SystemPowerIn` 更新前可估算

## 菜单栏功率显示

默认仅显示图标。在 Popover 底部打开「菜单栏显示功率」后：

| 模式 | 显示值 | 样式 |
|---|---|---|
| 电池供电 | 系统功耗 | `19W` |
| AC 充电 | AC 总输入 | `31W` |
| AC + 电池补充 | 系统功耗 | `⚠ 33W` |
| AC 供电 | 系统功耗 | `19W` |

- 数值四舍五入；超过 99 W 封顶为 `99W`
- macOS 菜单栏为系统单色，警告用 `⚠` 前缀（补充放电，或非补充场景下 >99 W）
- 偏好写入 `UserDefaults`（`showPowerInMenuBar`）

## 系统要求

- macOS 14.0（Sonoma）或更高
- Apple Silicon **MacBook**（内置电池）

## 安装

### 下载

从 [Releases](https://github.com/kDolphin/PowerTop/releases) 下载 `PowerTop.zip`：

1. 解压
2. 将 `PowerTop.app` 移入 `/Applications`
3. 首次启动：右键 → **打开**（未签名应用）

### 源码构建

```bash
git clone https://github.com/kdolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

`build.sh` 需要 Xcode 或版本匹配的 Swift 工具链，产出 `build/PowerTop.app` 与 `build/PowerTop.zip`。

## 技术栈

- **Swift 5** + **SwiftUI**（`MenuBarExtra`、独立 `Window` 场景）
- **Observation**（`@Observable` `PowerMonitor`）
- **IOKit** / **IOKit.ps**（`AppleSmartBattery`、IOPS 通知）
- **ServiceManagement**（`SMAppService` 登录项）
- 本地化：英文 + 简体中文（`Localizable.strings`，跟随系统语言）

## 更新内容

### v1.2.0

- 详细参数窗口重设计：合并当前电源与充电上下文；与 Popover 标签统一
- 平铺布局，去掉折叠组；修复首次打开蓝色焦点框
- 启动即监控；`uiRefreshToken` 修复菜单栏休眠唤醒后不刷新
- 电池 idle 时 `SystemLoad` 回退，修复 0 W
- 电芯压差摘要

### v1.1.9

- 插上电源滞后遥测：残留 `SystemPowerIn` 不再跳过「AC 连接中」
- 休眠/唤醒 block 观察者；定时器重建前 invalidate
- 无电池设备横幅与菜单栏警告；登录项失败内联错误

### v1.1.8

- Popover 280 px 满宽；ZStack + PreferenceKey 动态高度
- 拔掉后可靠停留电池模式；改进 `ExternalConnected` 跟踪

[更早版本 →](https://github.com/kDolphin/PowerTop/releases)

## 截图

*菜单栏 Popover：AC 充电状态与功率流向图*

*详细参数窗口：电池健康、电芯与功耗数据*

## 本地化

跟随系统语言；可在 **系统设置 → 通用 → 语言与地区 → 应用程序** 单独指定 PowerTop 语言。

## 许可证

MIT。详见 [LICENSE](LICENSE)。
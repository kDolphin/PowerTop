# PowerTop

**[English](README.md)** | **简体中文**

一个原生 macOS 菜单栏应用，用于 Apple Silicon MacBook 的实时功耗监控。

> **⚠️ 仅支持 MacBook** — PowerTop 需要内置电池。Mac mini、Mac Studio、Mac Pro 不受支持。

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

## 功能特性

- **实时功率流向图** — 可视化 AC 适配器、电池和系统之间的功率流向
- **补充放电检测** — 适配器功率不足时，显示 AC 与电池并联向系统供电
- **菜单栏功率显示** — 可选择在菜单栏显示实时功率，按场景切换数值与警告标识
- **插拔电源即时响应** — 事件驱动状态机在拔掉或插入充电器时立即切换状态
- **瞬时功率指标** — 系统功耗、AC 适配器输出、电池充放电功率
- **电池健康** — 健康度百分比、循环次数、设计容量、温度
- **详细参数** — 电芯数据、充电详情、生命周期统计
- **电源变更通知** — 插拔电源即时刷新界面
- **双语支持** — 中文和英文，跟随系统语言
- **开机启动** — 可选登录时自动启动
- **原生 macOS 体验** — SwiftUI 构建，菜单栏应用，无 Dock 图标

## 更新内容

### v1.2.0

- **详细参数窗口重设计** — 合并「当前电源」与充电状态，标签与 Popover 统一，去掉内部遥测术语
- **平铺布局** — 所有分区默认展开（无折叠）；修复首次打开时的蓝色焦点框
- **菜单栏即时更新** — 启动即开始监控；休眠唤醒后无需点击即可刷新读数
- **0W 修复** — 电池供电 idle 状态下，电池遥测符号不明确时回退使用 `SystemLoad`
- **电芯均衡摘要** — 详情页显示电芯压差与可读状态

### v1.1.9

- **插上电源滞后数据修复** — 上一段 AC 会话残留的 `SystemPowerIn` 不再导致跳过「AC 连接中」
- **休眠/唤醒可靠性** — 改用 block 观察者；休眠时停止轮询、唤醒后恢复
- **定时器与 IOPS 健壮性** — 定时器重建前先 invalidate；插拔刷新合并调度
- **不支持设备提示** — 未检测到内置电池时显示横幅与菜单栏警告
- **登录时启动反馈** — 注册失败时显示内联错误提示

### v1.1.8

- **修复 Popover 右边空白** — 内容正确撑满 280px 宽度
- **改进 Popover 动态尺寸** — ZStack + PreferenceKey 获得更可靠的高度测量
- **状态机正确性修复** — 拔掉后可靠停留在电池模式；更好跟踪 `ExternalConnected`

[更早版本 →](https://github.com/kDolphin/PowerTop/releases)

## 截图

*菜单栏 Popover 展示 AC 充电状态与功率流向图*

*详细参数窗口展示电池与功耗数据*

## 系统要求

- macOS 14.0（Sonoma）或更高版本
- Apple Silicon **MacBook**（需要内置电池，Mac mini / Mac Studio / Mac Pro 不受支持）

## 安装

### 下载安装

从 [Releases 页面](https://github.com/kDolphin/PowerTop/releases) 下载最新版本。

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

## 工作原理

PowerTop 通过 macOS IOKit 的 `AppleSmartBattery` 服务读取功耗数据，主要使用 `PowerTelemetryData` 字典：

| IOKit 属性 | 说明 |
|---|---|
| `SystemLoad` | 系统总功耗 |
| `SystemPowerIn` | AC 适配器输入的直流功率 |
| `BatteryPower` | 电池充放电功率 |
| `Amperage` × `Voltage` | 带符号的电池功率（负 = 充电，正 = 放电） |
| `ExternalConnected` | AC 适配器是否物理连接 |

### 连接状态机

PowerTop 在 IOKit 遥测之上叠加事件驱动状态机：

| 阶段 | 触发条件 | 界面 |
|---|---|---|
| **电池供电** | 检测到拔掉（`ExternalConnected=false`） | 立即显示电池放电，忽略滞后的 AC 数据 |
| **AC 连接中** | 检测到插入（`ExternalConnected=true`） | 显示「AC 连接中」，等待 `SystemPowerIn` 或充电信号 |
| **AC 稳定** | 遥测收敛或 3 秒超时 | 进入充电 / 供电 / 补充放电 |

### 功率状态

PowerTop 识别四种工作模式：

| 模式 | 条件 | 功率流向 |
|---|---|---|
| **电池供电** | 未插电源 | 电池 → 系统 |
| **AC 供电** | 插电源，适配器满足负载，未充电 | AC → 系统 |
| **AC 充电** | 插电源，AC 有剩余功率 | AC → 系统 + 电池 |
| **AC + 电池补充** | 插电源，适配器无法满足峰值负载 | AC → 系统，电池 → 系统 |

### 菜单栏功率显示

开启后，菜单栏显示四舍五入的功率文字（如 `19W`）。实际功率超过 99 W 时，显示封顶为 `99W`。macOS 菜单栏为系统单色文字，因此用 `⚠` 前缀代替红/橙色。

| 模式 | 菜单栏显示 | 文字样式 |
|---|---|---|
| **电池供电** | 系统功耗 | `19W` |
| **AC 充电** | AC 总输入 | `31W` |
| **AC + 电池补充** | 系统功耗 | `⚠ 33W` — 插着 AC 电池仍在放电 |
| **AC 供电** | 系统功耗 | `19W` |

**警告规则**

- **`⚠` 前缀** — 补充放电：已连接 AC，但电池仍在向系统供电
- **`⚠` 前缀** — 非补充放电场景下，功率超过 99 W（文字仍显示 `99W`）
- **无前缀** — 其余情况

### 功率计算逻辑

- **AC 充电时**：系统功耗 = `SystemPowerIn` - 充电功率（AC 输入减去向电池供电的部分）
- **电池供电时**：系统功耗 = `BatteryPower`（放电功率 = 系统消耗）
- **补充放电时**：系统功耗 = `SystemLoad`；电池贡献功率来自带符号的 `Amperage` / `BatteryPower`
- **充放电功率**：由带符号的 `Amperage × Voltage / 1,000,000` 计算，并与 `BatteryPower` 遥测交叉验证
- **拔掉时**：`ExternalConnected=false` 优先，忽略滞后的 `SystemPowerIn` 和 `IsCharging`
- **插上时**：立即信任 `ExternalConnected=true`，在 `SystemPowerIn` 更新前可估算功率
- **滞后标志处理**：当 `IsCharging` 与电流极性或能量平衡矛盾时，以实际功率流向信号为准

## 本地化

PowerTop 支持中文和英文，自动跟随系统语言。也可在 **系统设置 → 通用 → 语言与地区 → 应用程序** 中单独指定。

## 许可证

MIT 许可证。详见 [LICENSE](LICENSE)。
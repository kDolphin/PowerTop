# PowerTop

**[English](README.md)** | **简体中文**

一个简洁轻量的菜单栏应用，实时显示你的 MacBook 正在消耗多少功率。

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" />
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-green" />
  <img src="https://img.shields.io/badge/license-MIT-orange" />
</p>

> **仅支持 MacBook** — 需要配备内置电池的 Apple Silicon MacBook。

## 终于能看到 MacBook 真实的功耗了

macOS 从来不会直接告诉你「现在系统正在消耗多少瓦」。PowerTop 解决了这个问题。

它把清晰、实时的功率信息放在菜单栏和弹窗里，让你随时知道电脑的用电情况。

## 主要功能

- **菜单栏功率显示（可选）** — 需要时可在菜单栏直接看到 `23W` 这样的实时数字。
- **功率流向图** — 一目了然地看到功率是来自充电器、电池，还是两者同时提供。
- **即时功率数据** — 系统功耗、充电器输出、电池充电或放电功率。
- **充电器负载情况** — 显示你的适配器功率以及当前使用率。
- **电池概览** — 快速查看电量、健康度、温度和循环次数。
- **详细参数窗口** — 点击可查看电芯电压、充电状态、历史统计等更多信息。

数据实时更新，即使在插拔电源的瞬间也能保持准确可靠。

## 为什么用户喜欢用它

- 想知道 MacBook 实际消耗了多少功率
- 想了解自己的充电器在高负载时是否够用
- 想看到电池什么时候在帮忙供电
- 希望有一个简单漂亮的方式查看电池健康和充电行为

它是一个小巧的原生 Mac 应用，只做好一件事 —— 没有多余功能，没有订阅。

## 安装方式

### 下载安装（推荐）

从 [Releases](https://github.com/kDolphin/PowerTop/releases) 页面下载最新的 `PowerTop.zip`：

1. 解压文件
2. 把 `PowerTop.app` 拖到「应用程序」文件夹
3. 首次启动：右键点击应用 → **打开**（应用未签名）

### 从源码构建

```bash
git clone https://github.com/kDolphin/PowerTop.git
cd PowerTop
bash build.sh
open build/PowerTop.app
```

## 系统要求

- Apple Silicon MacBook（M 系列芯片）
- macOS 14（Sonoma）或更高版本

## 使用方法

1. 打开 PowerTop，图标会出现在菜单栏。
2. 点击图标即可看到功率流向图和当前各项数据。
3. 在弹窗底部开启「菜单栏显示功率」，即可让功率数值常驻菜单栏。
4. 点击「详细参数」可查看完整的功率和电池信息。

## 截图展示

*弹出窗口：功率流向图与实时数据*

*详细参数窗口：电池健康与更多信息*

## 更新内容

最新改进和完整更新日志请查看 [Releases](https://github.com/kDolphin/PowerTop/releases) 页面。

## 许可证

MIT 许可证。详见 [LICENSE](LICENSE)。

import SwiftUI

struct PopoverView: View {
    let monitor: PowerMonitor
    @Environment(\.openWindow) private var openWindow

    private var data: PowerData { monitor.currentData }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 12)
            powerFlowDiagram.padding(.vertical, 10)
            Divider().padding(.horizontal, 12)
            metricsSection.padding(.horizontal, 14).padding(.vertical, 10)
            Divider().padding(.horizontal, 12)
            batterySection.padding(.horizontal, 14).padding(.vertical, 10)
            Divider().padding(.horizontal, 12)
            footerSection.padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(width: 280)
        .onAppear {
            // MenuBarExtra popover auto-focuses the first button; clear it to avoid the blue focus ring.
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: data.effectiveIsOnAC ? "powerplug.fill" : "battery.50")
                .foregroundStyle(data.effectiveIsOnAC ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.powerSourceDescription)
                    .font(.system(size: 13, weight: .semibold))
                Text(String(format: "%.1f W", data.headerPowerW))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Power Flow Diagram

    private var powerFlowDiagram: some View {
        VStack(spacing: 6) {
            if data.effectiveIsOnAC {
                if data.isSupplementalDischarge {
                    supplementalDischargeDiagram
                } else {
                    acPoweredDiagram
                }
            } else {
                batteryPoweredDiagram
            }
        }
        .padding(.horizontal, 14)
    }

    private var acPoweredDiagram: some View {
        VStack(spacing: 6) {
            sourceBox(
                title: String(localized: "AC Powered"),
                value: String(format: "%.1f W", data.effectiveACOutputW),
                color: .green,
                icon: "powerplug.fill"
            )
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            if data.isBatteryCharging {
                HStack(spacing: 10) {
                    destBox(
                        title: String(localized: "Battery Charging"),
                        value: String(format: "%.1f W", data.batteryChargeRateW),
                        color: .blue,
                        icon: "battery.100.bolt"
                    )
                    destBox(
                        title: String(localized: "System"),
                        value: String(format: "%.1f W", data.systemPowerW),
                        color: .primary,
                        icon: "desktopcomputer"
                    )
                }
            } else {
                destBox(
                    title: String(localized: "System"),
                    value: String(format: "%.1f W", data.systemPowerW),
                    color: .primary,
                    icon: "desktopcomputer"
                )
            }
        }
    }

    private var supplementalDischargeDiagram: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                sourceBox(
                    title: String(localized: "AC Powered"),
                    value: String(format: "%.1f W", data.effectiveACOutputW),
                    color: .green,
                    icon: "powerplug.fill"
                )
                sourceBox(
                    title: String(localized: "Battery Discharge"),
                    value: String(format: "%.1f W", data.batterySupplementalW),
                    color: .orange,
                    icon: "battery.50"
                )
            }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            destBox(
                title: String(localized: "System"),
                value: String(format: "%.1f W", data.systemPowerW),
                color: .primary,
                icon: "desktopcomputer"
            )
        }
    }

    private var batteryPoweredDiagram: some View {
        VStack(spacing: 6) {
            sourceBox(
                title: String(localized: "Battery Discharge"),
                value: String(format: "%.1f W", data.systemPowerW),
                color: .orange,
                icon: "battery.50"
            )
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            destBox(
                title: String(localized: "System"),
                value: String(format: "%.1f W", data.systemPowerW),
                color: .primary,
                icon: "desktopcomputer"
            )
        }
    }

    private func sourceBox(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private func destBox(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 7) {
            PowerRowView(icon: "desktopcomputer", iconColor: .primary, label: String(localized: "System Power"), value: String(format: "%.1f W", data.systemPowerW))
            if data.effectiveIsOnAC {
                PowerRowView(icon: "powerplug.fill", iconColor: .green, label: String(localized: "AC Adapter Output"), value: String(format: "%.1f W", data.effectiveACOutputW))
            }
            if data.isBatteryCharging {
                PowerRowView(icon: "arrow.down.to.line", iconColor: .blue, label: String(localized: "Battery Charging"), value: String(format: "%.1f W", data.batteryChargeRateW))
            } else if data.isSupplementalDischarge {
                PowerRowView(icon: "arrow.up.right.and.arrow.down.left", iconColor: .orange, label: String(localized: "Battery Supplement"), value: String(format: "%.1f W", data.batterySupplementalW))
            }
            if data.effectiveIsOnAC && data.acAdapterWattage > 0 {
                PowerRowView(
                    icon: "bolt.fill",
                    iconColor: .green,
                    label: String(localized: "Charger Spec"),
                    value: "\(data.acAdapterWattage) W" + (data.adapterDescription.map { " (\($0))" } ?? ""),
                    wrapsValue: data.adapterDescription != nil
                )
            }
            if data.dataSource == .legacy {
                PowerRowView(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .yellow,
                    label: String(localized: "Data Source"),
                    value: String(localized: "Estimation Mode"),
                    wrapsValue: true
                )
            }
        }
    }

    // MARK: - Battery

    private var batterySection: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text(String(localized: "Battery Level")).font(.system(size: 12)).foregroundStyle(.secondary)
                ProgressView(value: Double(data.batteryPercent), total: 100)
                    .progressViewStyle(.linear)
                    .tint(data.batteryPercent <= 20 ? .red : (data.batteryPercent <= 50 ? .orange : .green))
                Text("\(data.batteryPercent)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
            }

            if let health = data.batteryHealthPercent {
                HStack(spacing: 8) {
                    Text(String(localized: "Health")).font(.system(size: 12)).foregroundStyle(.secondary)
                    ProgressView(value: Double(health), total: 100)
                        .progressViewStyle(.linear)
                        .tint(health >= 80 ? .green : (health >= 60 ? .orange : .red))
                    Text("\(health)%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(health >= 80 ? .green : (health >= 60 ? .orange : .red))
                }
            }

            if let temp = data.batteryTemperatureC {
                PowerRowView(icon: "thermometer.medium", iconColor: temp > 40 ? .red : .secondary, label: String(localized: "Battery Temp"), value: String(format: "%.1f °C", temp))
            }
            if let cycles = data.cycleCount {
                PowerRowView(icon: "arrow.triangle.2.circlepath", iconColor: .secondary, label: String(localized: "Cycle Count"), value: "\(cycles)" + (data.designCycleCount.map { "/\($0)" } ?? ""))
            }
            if let voltage = data.batteryVoltageMV {
                PowerRowView(icon: "waveform.path", iconColor: .secondary, label: String(localized: "Battery Voltage"), value: String(format: "%.2f V", Double(voltage) / 1000.0))
            }
            if let reason = data.notChargingReasonDescription, data.effectiveIsOnAC && !data.isBatteryCharging {
                PowerRowView(
                    icon: "info.circle",
                    iconColor: .blue,
                    label: String(localized: "Not Charging Reason"),
                    value: reason,
                    wrapsValue: true
                )
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            Button {
                openDetailWindow()
            } label: {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text(String(localized: "Details"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            HStack {
                Toggle(String(localized: "Launch at Login"), isOn: Binding(
                    get: { monitor.launchAtLogin },
                    set: { monitor.launchAtLogin = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))

                Spacer()

                Text(AppInfo.versionLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                Button(String(localized: "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func openDetailWindow() {
        let detailTitle = String(localized: "PowerTop Details")
        // If window already exists, bring it to front
        for window in NSApp.windows {
            if window.title == detailTitle {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        // Otherwise open new window directly
        openWindow(id: "detail")
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let openDetailWindow = Notification.Name("com.kdolphin.powertop.openDetailWindow")
    static let iOPowerSourceChanged = Notification.Name("com.kdolphin.powertop.iOPowerSourceChanged")
}

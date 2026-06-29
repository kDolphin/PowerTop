import SwiftUI

private struct PopoverHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PopoverHeightObserver: View {
    // Pure reporter: only emits preference. No direct @State mutation or fit calls from
    // inside GeometryReader (prevents "modifying state during view update"). React via
    // .onPreferenceChange on the parent (review Bug 4).
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: PopoverHeightPreferenceKey.self, value: geo.size.height)
        }
    }
}

struct PopoverView: View {
    let monitor: PowerMonitor
    @Environment(\.openWindow) private var openWindow
    @State private var measuredContentHeight: CGFloat = 0
    @State private var cachedPopoverWindow: NSWindow?   // cached for robust window targeting (review Bug 3)

    private var data: PowerData { monitor.currentData }

    private var layoutSignature: String {
        [
            String(describing: data.connectionPhase),
            data.effectiveIsOnAC ? "ac" : "bat",
            data.isConnectingAC ? "conn" : "stable",
            data.isBatteryCharging ? "chg" : data.isSupplementalDischarge ? "sup" : "plain",
            data.notChargingReasonDescription != nil ? "reason" : "noreason",
            data.batteryHealthPercent != nil ? "health" : "nohealth",
            data.effectiveIsOnAC && data.acAdapterWattage > 0 ? "spec" : "nospec",
        ].joined(separator: "-")
    }

    var body: some View {
        // Single tight content container. We rely on .fixedSize(vertical: true) + preference measurement
        // so the window can be set to the exact ideal height of the content. This avoids the previous
        // wrapper + Spacer which could cause extra allocated space to appear as blanks above/below.
        contentSections
            .frame(width: Self.popoverWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(PopoverHeightObserver())
            .onPreferenceChange(PopoverHeightPreferenceKey.self) { height in
                if height > 1 {
                    measuredContentHeight = height
                    // Dispatch to allow the current update/layout pass to settle before resizing the NSWindow.
                    DispatchQueue.main.async {
                        fitPopoverWindow(to: height)
                    }
                }
            }
            .onChange(of: layoutSignature) { _, _ in
                // Major visual change (different diagram or phase). Re-fit shortly after SwiftUI updates.
                scheduleWindowFit(after: 0.04)
            }
            .onAppear {
                scheduleWindowFit(after: 0)
                DispatchQueue.main.async {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
    }

    // The actual stacked sections (no extra frame/fixed/background here).
    private var contentSections: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 12)
            powerFlowDiagram
                .padding(.vertical, 8)
            Divider().padding(.horizontal, 12)
            metricsSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            Divider().padding(.horizontal, 12)
            batterySection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            Divider().padding(.horizontal, 12)
            footerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
    }

    private static let popoverWidth: CGFloat = 280

    private var headerIconColor: Color {
        if data.isConnectingAC { return .secondary }
        return data.effectiveIsOnAC ? .green : .orange
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: data.effectiveIsOnAC ? "powerplug.fill" : "battery.50")
                .foregroundStyle(headerIconColor)
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
        .padding(.bottom, 8)
    }

    // MARK: - Power Flow Diagram

    @ViewBuilder
    private var powerFlowDiagram: some View {
        Group {
            if data.isConnectingAC {
                connectingACDiagram
            } else if data.isSupplementalDischarge {
                supplementalDischargeDiagram
            } else if data.effectiveIsOnAC {
                acPoweredDiagram
            } else {
                batteryPoweredDiagram
            }
        }
        .padding(.horizontal, 14)
    }

    private var connectingACDiagram: some View {
        VStack(spacing: 6) {
            sourceBox(
                title: String(localized: "AC Connecting"),
                value: "—",
                color: .secondary,
                icon: "powerplug.fill"
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
        VStack(spacing: 6) {
            PowerRowView(icon: "desktopcomputer", iconColor: .primary, label: String(localized: "System Power"), value: String(format: "%.1f W", data.systemPowerW))

            if data.effectiveIsOnAC && !data.isConnectingAC {
                PowerRowView(icon: "powerplug.fill", iconColor: .green, label: String(localized: "AC Adapter Output"), value: String(format: "%.1f W", data.effectiveACOutputW))
            }

            if data.isBatteryCharging {
                PowerRowView(
                    icon: "arrow.down.to.line",
                    iconColor: .blue,
                    label: String(localized: "Battery Charging"),
                    value: String(format: "%.1f W", data.batteryChargeRateW)
                )
            } else if data.isSupplementalDischarge {
                PowerRowView(
                    icon: "arrow.up.right.and.arrow.down.left",
                    iconColor: .orange,
                    label: String(localized: "Battery Supplement"),
                    value: String(format: "%.1f W", data.batterySupplementalW)
                )
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
        VStack(spacing: 6) {
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
            if let reason = data.notChargingReasonDescription,
               data.effectiveIsOnAC && !data.isConnectingAC && !data.isBatteryCharging {
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

            VStack(alignment: .leading, spacing: 8) {
                Toggle(String(localized: "Launch at Login"), isOn: Binding(
                    get: { monitor.launchAtLogin },
                    set: { monitor.launchAtLogin = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))

                Toggle(String(localized: "Show Power in Menu Bar"), isOn: Binding(
                    get: { monitor.showPowerInMenuBar },
                    set: { monitor.showPowerInMenuBar = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            HStack {
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

    private func scheduleWindowFit(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard measuredContentHeight > 1 else { return }
            // When called due to layoutSignature change, we want to force a resize attempt
            // even if previous window size looked similar (to handle cases where measurement
            // was captured against a stale container size).
            fitPopoverWindow(to: measuredContentHeight, force: true)
        }
    }

    private func popoverWindow() -> NSWindow? {
        if let cached = cachedPopoverWindow, cached.isVisible {
            return cached
        }
        // More defensive search: prefer visible windows of approximately our width that are
        // not the detail window. Avoids picking unrelated windows (review Bug 3).
        let candidates = NSApp.windows.filter { w in
            w.isVisible &&
            abs(w.frame.width - Self.popoverWidth) < 12 &&
            w.frame.height > 60 && w.frame.height < 800 &&
            !w.title.lowercased().contains("detail")
        }
        let found = candidates.first
        if let f = found {
            cachedPopoverWindow = f   // @State assignment is allowed
        }
        return found
    }

    private func fitPopoverWindow(to contentHeight: CGFloat, force: Bool = false) {
        DispatchQueue.main.async {
            guard contentHeight > 1 else { return }
            guard let window = self.popoverWindow() else { return }

            let heightDiff = abs(window.frame.height - contentHeight)
            let widthDiff = abs(window.frame.width - Self.popoverWidth)
            if !force && heightDiff < 1 && widthDiff < 1 {
                return
            }

            var frame = window.frame
            // Only shift origin when width actually changed; unconditional shift could push popover off menu item.
            if widthDiff > 1 {
                frame.origin.x += (frame.size.width - Self.popoverWidth) / 2
            }
            frame.origin.y += frame.size.height - contentHeight
            frame.size.width = Self.popoverWidth
            frame.size.height = contentHeight
            window.setFrame(frame, display: true, animate: false)
        }
    }

    private func openDetailWindow() {
        let detailTitle = String(localized: "PowerTop Details")
        for window in NSApp.windows {
            if window.title == detailTitle {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        openWindow(id: "detail")
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let openDetailWindow = Notification.Name("com.kdolphin.powertop.openDetailWindow")
    static let iOPowerSourceChanged = Notification.Name("com.kdolphin.powertop.iOPowerSourceChanged")
}
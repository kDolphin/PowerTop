import AppKit
import SwiftUI

extension Notification.Name {
    static let powerTopOpenDetails = Notification.Name("powerTopOpenDetails")
}

/// Menu bar extra implemented as NSStatusItem + NSPopover (system chrome, intrinsic size).
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let monitor: PowerMonitor
    private let statusItem: NSStatusItem
    private let labelHost: NSHostingView<MenuBarLabelView>
    private let popover = NSPopover()
    private var eventMonitor: Any?

    init(monitor: PowerMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        labelHost = NSHostingView(rootView: MenuBarLabelView(monitor: monitor))
        super.init()
        configureStatusItem()
        configurePopover()
        startObservingMonitor()
        installClickMonitor()
        updateStatusItemLayout()
    }

    func invalidate() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        popover.performClose(nil)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .noImage
        button.title = ""
        button.subviews.forEach { $0.removeFromSuperview() }
        labelHost.translatesAutoresizingMaskIntoConstraints = true
        labelHost.autoresizingMask = [.width, .height]
        button.addSubview(labelHost)
        button.sendAction(on: [.leftMouseUp])
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = StatusPopoverContent(
            monitor: monitor,
            openDetails: { [weak self] in self?.openDetails() },
            onMeasuredSize: { [weak self] size in
                self?.applyPopoverSize(size)
            }
        )
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: PopoverView.preferredWidth, height: 420)
    }

    private func startObservingMonitor() {
        observeMonitor()
    }

    private func observeMonitor() {
        withObservationTracking {
            _ = monitor.uiRefreshToken
            _ = monitor.showPowerInMenuBar
            _ = monitor.isDataAvailable
            _ = monitor.currentData.menuBarPowerShowsWarning
            _ = monitor.currentData.effectiveIsOnAC
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItemLayout()
                self?.observeMonitor()
            }
        }
    }

    private func updateStatusItemLayout() {
        labelHost.rootView = MenuBarLabelView(monitor: monitor)
        let width = MenuBarLabelView.preferredWidth(for: monitor)
        let buttonHeight = statusItem.button?.bounds.height ?? 0
        let height = buttonHeight > 1 ? buttonHeight : 22
        labelHost.frame = NSRect(x: 0, y: 0, width: width, height: height)
        statusItem.length = width
    }

    @objc private func statusItemClicked() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if let hosting = popover.contentViewController {
            let fitted = hosting.view.fittingSize
            if fitted.width > 1, fitted.height > 1 {
                applyPopoverSize(fitted)
            }
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func applyPopoverSize(_ size: CGSize) {
        let width = max(size.width, PopoverView.preferredWidth)
        let height = max(size.height, 80)
        let next = NSSize(width: width.rounded(), height: height.rounded())
        guard abs(popover.contentSize.width - next.width) > 0.5
            || abs(popover.contentSize.height - next.height) > 0.5 else { return }
        popover.contentSize = next
    }

    func openDetails() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        let detailTitle = String(localized: "PowerTop Details")
        if let window = NSApp.windows.first(where: { $0.title == detailTitle }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        NotificationCenter.default.post(name: .powerTopOpenDetails, object: nil)
    }

    /// Swallow the status-item click that would reopen a transient popover just closed by the same click.
    private func installClickMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let button = self.statusItem.button else { return event }
            guard event.window === button.window else { return event }
            if self.popover.isShown {
                self.popover.performClose(nil)
                return nil
            }
            return event
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }
}

private struct PopoverMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct StatusPopoverContent: View {
    let monitor: PowerMonitor
    let openDetails: () -> Void
    let onMeasuredSize: (CGSize) -> Void

    var body: some View {
        PopoverView(monitor: monitor, openDetails: openDetails)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PopoverMeasuredSizeKey.self, value: proxy.size)
                }
            }
            .onPreferenceChange(PopoverMeasuredSizeKey.self) { size in
                guard size.width > 1, size.height > 1 else { return }
                onMeasuredSize(size)
            }
    }
}

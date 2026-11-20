import SwiftUI
import AppKit
import Combine

@main
struct DaybarApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class Delegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let reminders = ReminderPresenter()
    private var status: NSStatusItem?
    private let popover = NSPopover()
    private var observation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status = item
        item.autosaveName = "Daybar"
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.toolTip = "Open your daily schedule"
        popover.behavior = .transient
        popover.contentSize = DaybarLayout.dashboard
        popover.contentViewController = NSHostingController(rootView: Dashboard(store: store))
        store.showReminder = { [weak self] block in
            guard let self else { return }
            reminders.show(block, animated: store.animated, accent: store.appearance.accent, anchor: status?.button)
        }
        // Subscribe to the value itself, rather than objectWillChange (which fires before mutation).
        observation = store.$timeline.map(\.current).removeDuplicates().sink { [weak self] block in
            guard let button = self?.status?.button else { return }
            button.image = block.flatMap { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) }
            button.imagePosition = .imageLeading
            let title = block?.displayTitle ?? "Daybar"
            button.title = button.image == nil ? "◷ " + title : title
            button.setAccessibilityLabel(title)
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: .NSSystemTimeZoneDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: .NSSystemClockDidChange, object: nil)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        reminders.close()
        observation = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didWake() { store.synchronize() }
    @objc private func clockChanged() { store.synchronize() }

    @objc private func toggle() {
        guard let button = status?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            store.refreshLogin()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

import SwiftUI
import AppKit
import ServiceManagement
import Combine

@MainActor
final class Store: ObservableObject {
    @Published var blocks: [Block] { didSet { save() } }
    @Published var appearance: Appearance { didSet {
        if let data = try? JSONEncoder().encode(appearance) { UserDefaults.standard.set(data, forKey: "appearance") }
    } }
    @Published var quiet = false
    @Published var animated: Bool { didSet { UserDefaults.standard.set(animated, forKey: "animated") } }
    @Published var now = Date()
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginMessage: String?
    private var timer: Timer?
    private var previous: Date = Date()

    var showReminder: ((Block) -> Void)?
    init() {
        appearance = UserDefaults.standard.data(forKey: "appearance").flatMap { try? JSONDecoder().decode(Appearance.self, from: $0) } ?? Appearance()
        blocks = UserDefaults.standard.data(forKey: "blocks").flatMap { try? JSONDecoder().decode([Block].self, from: $0) } ?? Block.defaults
        animated = UserDefaults.standard.object(forKey: "animated") as? Bool ?? true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func save() {
        if let data = try? JSONEncoder().encode(blocks) { UserDefaults.standard.set(data, forKey: "blocks") }
    }
    func tick() {
        let date = Date()
        defer { previous = date; now = date }
        // After sleep, show only the latest transition, never a backlog.
        if let block = Schedule.transition(blocks, after: previous, through: date), !quiet { showReminder?(block) }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLogin()
        } catch { loginMessage = error.localizedDescription; refreshLogin() }
    }
    func refreshLogin() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        if status == .requiresApproval { loginMessage = "Approve Daybar in System Settings → General → Login Items." }
        else if status == .enabled { loginMessage = nil }
    }
}

@main
struct DaybarApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class Delegate: NSObject, NSApplicationDelegate {
    let store = Store()
    var status: NSStatusItem!
    let popover = NSPopover()
    var panel: NSPanel?
    var observation: AnyCancellable?
    var dismissal: Task<Void, Never>?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.autosaveName = "Daybar"
        status.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        status.button?.target = self
        status.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 390, height: 530)
        popover.contentViewController = NSHostingController(rootView: Dashboard(store: store))
        store.showReminder = { [weak self] block in self?.present(block) }
        updateLabel()
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.updateLabel() }
        }
    }

    func updateLabel() {
        let current = Schedule.current(store.blocks, at: Date())
        status.button?.title = "◷ " + (current?.title ?? "Daybar")
        status.button?.toolTip = "Open your daily schedule"
    }
    @objc func toggle() {
        guard let button = status.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { store.refreshLogin(); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    func present(_ block: Block) {
        dismissal?.cancel()
        panel?.close()
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: 142), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: ReminderCard(block: block, animated: store.animated, accent: store.appearance.accent))
        if let button = status.button, let parent = button.window {
            let anchor = parent.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = parent.screen?.visibleFrame ?? anchor
            window.setFrameOrigin(NSPoint(x: max(visible.minX, min(anchor.midX - 185, visible.maxX - 370)), y: anchor.minY - 150))
        } else { window.center() }
        panel = window
        window.orderFrontRegardless()
        dismissal = Task { @MainActor [weak self, weak window] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                window?.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            window?.close()
            self?.panel = nil
        }
    }
}

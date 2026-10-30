import SwiftUI
import AppKit

/// Shared dimensions prevent the AppKit window and its SwiftUI content from drifting apart.
enum DaybarLayout {
    static let dashboard = CGSize(width: 390, height: 530)
    static let reminderWindow = CGSize(width: 370, height: 142)
    static let reminderCard = CGSize(width: 346, height: 98)
    static let reminderDuration: Duration = .seconds(6)
}

@MainActor
final class ReminderPresenter {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(_ block: Block, animated: Bool, accent: Color, anchor button: NSStatusBarButton?) {
        close()
        let size = DaybarLayout.reminderWindow
        let window = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: ReminderCard(block: block, animated: animated, accent: accent))
        if let button, let parent = button.window, let screen = parent.screen {
            let anchor = parent.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: max(visible.minX, min(anchor.midX - size.width / 2, visible.maxX - size.width)),
                y: max(visible.minY, anchor.minY - size.height - 8)))
        } else { window.center() }
        panel = window
        window.orderFrontRegardless()
        dismissal = Task { @MainActor [weak self, weak window] in
            do { try await Task.sleep(for: DaybarLayout.reminderDuration) }
            catch { return }
            guard let self, let window, self.panel === window else { return }
            if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                await NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    window.animator().alphaValue = 0
                }
            }
            guard !Task.isCancelled, self.panel === window else { return }
            window.close()
            self.panel = nil
            self.dismissal = nil
        }
    }

    func close() {
        dismissal?.cancel()
        dismissal = nil
        panel?.close()
        panel = nil
    }
}

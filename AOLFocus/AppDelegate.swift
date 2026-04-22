import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let closeAOLFocusPopover = Notification.Name("closeAOLFocusPopover")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var session = FocusSession()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (belt + suspenders with LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.closePopover()
            }
        }

        // Close popover from SwiftUI title bar buttons
        NotificationCenter.default.addObserver(forName: .closeAOLFocusPopover, object: nil, queue: .main) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.toolTip = "You've Got Focus"
        button.action = #selector(togglePopover)
        button.target = self
        setMenuBarIcon(button: button)

        // Update button on every tick — show live countdown when active
        Publishers.CombineLatest(session.$state, session.$remainingSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak button] state, remaining in
                guard let self, let button else { return }
                switch state {
                case .active:
                    let mins = remaining / 60
                    let secs = remaining % 60
                    button.image = nil
                    button.title = String(format: "📞 %d:%02d", mins, secs)
                    button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                case .paused:
                    let mins = remaining / 60
                    let secs = remaining % 60
                    button.image = nil
                    button.title = String(format: "⏸ %d:%02d", mins, secs)
                    button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                default:
                    button.title = ""
                    self.setMenuBarIcon(button: button)
                }
                self.statusItem.length = NSStatusItem.variableLength
            }.store(in: &cancellables)
    }

    private func setMenuBarIcon(button: NSStatusBarButton) {
        if let img = NSImage(named: "MenuBarIcon") {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 15)
            button.image = img
            button.imagePosition = .imageOnly
        } else {
            button.title = "🌐"
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(session)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        // Anchor to the horizontal center of the button so the popover
        // doesn't shift left/right as the timer text changes width
        let center = CGRect(
            x: button.bounds.midX - 1,
            y: button.bounds.minY,
            width: 2,
            height: button.bounds.height
        )
        popover.show(relativeTo: center, of: button, preferredEdge: .minY)
    }

    func closePopover() {
        popover.close()
    }
}

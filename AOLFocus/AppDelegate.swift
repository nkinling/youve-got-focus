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

        button.title = "🌐"
        button.font = NSFont.systemFont(ofSize: 14)
        button.toolTip = "AOL Focus — You've Got Minutes!"
        button.action = #selector(togglePopover)
        button.target = self

        // Update button on every tick — show live countdown when active
        Publishers.CombineLatest(session.$state, session.$remainingSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak button] state, remaining in
                guard let button else { return }
                switch state {
                case .active:
                    let mins = remaining / 60
                    let secs = remaining % 60
                    button.title = String(format: "📞 %d:%02d", mins, secs)
                    button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                case .paused:
                    let mins = remaining / 60
                    let secs = remaining % 60
                    button.title = String(format: "⏸ %d:%02d", mins, secs)
                    button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                default:
                    button.title = "🌐"
                    button.font = NSFont.systemFont(ofSize: 14)
                }
                // Let the status item resize to fit the new title
                self?.statusItem.length = NSStatusItem.variableLength
            }.store(in: &cancellables)
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() {
        popover.close()
    }
}

import AppKit
import SwiftUI
import Combine

final class Menubar: NSObject, NSPopoverDelegate {
    let item: NSStatusItem
    let popover: NSPopover
    let store: Store
    private var cancellables = Set<AnyCancellable>()

    init(store: Store) {
        self.store = store
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let host = NSHostingController(rootView: ConfigView(store: store))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 510, height: 620)

        if let btn = item.button {
            btn.action = #selector(click(_:))
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()

        store.$config
            .map(\.enabled)
            .removeDuplicates()
            .sink { [weak self] enabled in self?.updateIcon(enabled: enabled) }
            .store(in: &cancellables)
        store.$controllerName
            .removeDuplicates()
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon(enabled: Bool? = nil) {
        guard let btn = item.button else { return }
        let isOn = enabled ?? store.config.enabled
        let name = isOn ? "gamecontroller" : "pause.circle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "macpad")
        img?.isTemplate = true
        btn.image = img
        btn.toolTip = isOn
            ? "macpad — active (\(store.controllerName ?? "no controller"))"
            : "macpad — paused"
    }

    @objc private func click(_ sender: Any?) {
        let ev = NSApp.currentEvent
        if ev?.type == .rightMouseUp {
            let menu = NSMenu()
            let toggle = NSMenuItem(title: store.config.enabled ? "Pause" : "Resume",
                                    action: #selector(toggleEnabled),
                                    keyEquivalent: "")
            toggle.target = self
            menu.addItem(toggle)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "Quit macpad", action: #selector(quit), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else if let btn = item.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func toggleEnabled() { store.config.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}

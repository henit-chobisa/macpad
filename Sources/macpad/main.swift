import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: Store!
    var pad: Pad!
    var menubar: Menubar!
    var hud: HUD!
    var hudManager: HUDManager!
    var hid: HIDListener!
    var keyboardManager: KeyboardManager!
    var keyboardHost: KeyboardHost!

    func applicationDidFinishLaunching(_ n: Notification) {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        if !trusted {
            print("Accessibility permission not granted. Input events will not post until granted.")
        }
        NSApp.setActivationPolicy(.accessory)
        store = Store()
        hudManager = HUDManager()
        hud = HUD(manager: hudManager, store: store)
        keyboardManager = KeyboardManager()
        keyboardHost = KeyboardHost(manager: keyboardManager)
        pad = Pad(store: store, hud: hudManager, keyboard: keyboardManager)
        menubar = Menubar(store: store)
        hid = HIDListener()
        hid.onHome     = { [weak self] p in self?.pad.hidButton("HOME",     pressed: p) }
        hid.onShare    = { [weak self] p in self?.pad.hidButton("SHARE",    pressed: p) }
        hid.onTouchpad = { [weak self] p in self?.pad.hidButton("TOUCHPAD", pressed: p) }
        hid.start()

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard ev.modifierFlags.contains([.command, .option, .control]) else { return }
            if ev.keyCode == 35 {
                DispatchQueue.main.async { self?.store.config.enabled.toggle() }
            } else if ev.keyCode == 40 {
                DispatchQueue.main.async { self?.keyboardManager.toggle() }
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

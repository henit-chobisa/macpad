import Cocoa
import GameController
import CoreGraphics
import Combine

final class Pad {
    let store: Store
    let hud: HUDManager
    let keyboard: KeyboardManager
    let haptics = Haptics()
    var active: GCController?
    var loc: CGPoint = .zero
    private var vel: CGVector = .zero

    private var repeats: [String: (action: ButtonAction, resolved: String, nextFire: Date)] = [:]
    private var kbRepeats: [String: Date] = [:]  // on-screen keyboard repeat schedule keyed by button name
    private var heldAction: [String: (action: ButtonAction, resolved: String)] = [:]
    private var lastFire: [String: Date] = [:]  // debounce duplicate events from overlapping sources (GC + HID)
    private var lastStickPublish: Date = .distantPast  // throttle the 120Hz tick down to ~30Hz for UI stick preview
    private var holdPrecision = false
    private var holdBoost = false
    private var shoulderPending: [String: DispatchWorkItem] = [:]
    private var shoulderChorded: Set<String> = []
    private let chordWindow: TimeInterval = 0.15
    private var leftDown = false
    private var rightDown = false
    private var centerDown = false
    // Sticky modifier flags from hold-modifier button actions. Applied to every
    // synthetic mouse / key event while held, so a user can do e.g. R1 (holdCtrl)
    // + D-pad→ = ctrl+right-arrow = switch space.
    private var heldMods: CGEventFlags = []
    private var cancellables = Set<AnyCancellable>()

    init(store: Store, hud: HUDManager, keyboard: KeyboardManager) {
        self.store = store
        self.hud = hud
        self.keyboard = keyboard
        syncLoc()

        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.bind(c) }
        }
        nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] n in
            guard let c = n.object as? GCController, let s = self, c === s.active else { return }
            s.active = nil
            s.store.controllerName = nil
        }

        GCController.shouldMonitorBackgroundEvents = true
        GCController.startWirelessControllerDiscovery {}
        for c in GCController.controllers() { bind(c) }

        store.$config
            .map(\.enabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled { self.releaseAll() }
                enabled ? self.haptics.pulseUp() : self.haptics.pulseDown()
            }
            .store(in: &cancellables)

        store.$config
            .map(\.hapticsEnabled)
            .removeDuplicates()
            .sink { [weak self] on in self?.haptics.enabled = on }
            .store(in: &cancellables)

        haptics.enabled = store.config.hapticsEnabled

        Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func syncLoc() {
        var p = NSEvent.mouseLocation
        if let s = NSScreen.main { p.y = s.frame.height - p.y }
        loc = p
    }

    private func bind(_ c: GCController) {
        active = c
        store.controllerName = c.vendorName ?? "Controller"
        haptics.attach(c)
        guard let gp = c.extendedGamepad else { return }
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("A", p) }
        gp.buttonB.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("B", p) }
        gp.buttonX.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("X", p) }
        gp.buttonY.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("Y", p) }
        gp.leftShoulder.pressedChangedHandler  = { [weak self] _, _, p in self?.onBtn("L1", p) }
        gp.rightShoulder.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("R1", p) }
        gp.leftTrigger.pressedChangedHandler   = { [weak self] _, _, p in self?.onBtn("L2", p) }
        gp.rightTrigger.pressedChangedHandler  = { [weak self] _, _, p in self?.onBtn("R2", p) }
        gp.dpad.up.pressedChangedHandler    = { [weak self] _, _, p in self?.onBtn("UP", p) }
        gp.dpad.down.pressedChangedHandler  = { [weak self] _, _, p in self?.onBtn("DOWN", p) }
        gp.dpad.left.pressedChangedHandler  = { [weak self] _, _, p in self?.onBtn("LEFT", p) }
        gp.dpad.right.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("RIGHT", p) }
        gp.buttonOptions?.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("OPT", p) }
        gp.buttonMenu.pressedChangedHandler     = { [weak self] _, _, p in self?.onBtn("MENU", p) }
        gp.leftThumbstickButton?.pressedChangedHandler  = { [weak self] _, _, p in self?.onBtn("L3", p) }
        gp.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("R3", p) }

        // Some controllers (Switch Pro, DualSense) expose Home/Share only through physicalInputProfile,
        // not the named GCExtendedGamepad properties. Walk the button dict and bind by keyword.
        for (id, btn) in c.physicalInputProfile.buttons {
            let u = id.uppercased()
            if u.contains("HOME") {
                btn.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("HOME", p) }
            } else if u.contains("SHARE") || u.contains("CAPTURE") {
                btn.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("SHARE", p) }
            } else if u == "TOUCHPAD BUTTON" {
                btn.pressedChangedHandler = { [weak self] _, _, p in self?.onBtn("TOUCHPAD", p) }
            }
        }
    }

    private func tick() {
        // key repeat
        let now = Date()
        for (k, r) in repeats where now >= r.nextFire {
            perform(r.action, down: true, for: r.resolved)
            perform(r.action, down: false, for: r.resolved)
            let rate = max(1, store.config.keyRepeatRate)
            repeats[k] = (r.action, r.resolved, now.addingTimeInterval(1.0 / rate))
        }

        // on-screen keyboard key repeat — only when the panel is still visible
        if keyboard.visible {
            for (name, next) in kbRepeats where now >= next {
                fireKb(name)
                let rate = max(1, store.config.keyRepeatRate)
                kbRepeats[name] = now.addingTimeInterval(1.0 / rate)
            }
        } else if !kbRepeats.isEmpty {
            kbRepeats.removeAll()
        }

        // Publish live stick state for UI preview. Throttled to ~30Hz and guarded by
        // a small movement threshold so we don't flood the main queue with 120Hz
        // updates that drive needless SwiftUI re-renders in ConfigView.
        if let gp = active?.extendedGamepad, now.timeIntervalSince(lastStickPublish) > 0.033 {
            let lp = CGPoint(x: CGFloat(gp.leftThumbstick.xAxis.value),
                             y: CGFloat(gp.leftThumbstick.yAxis.value))
            let rp = CGPoint(x: CGFloat(gp.rightThumbstick.xAxis.value),
                             y: CGFloat(gp.rightThumbstick.yAxis.value))
            let lMoved = abs(lp.x - store.leftStick.x) > 0.02 || abs(lp.y - store.leftStick.y) > 0.02
            let rMoved = abs(rp.x - store.rightStick.x) > 0.02 || abs(rp.y - store.rightStick.y) > 0.02
            if lMoved || rMoved {
                lastStickPublish = now
                DispatchQueue.main.async {
                    if lMoved { self.store.leftStick = lp }
                    if rMoved { self.store.rightStick = rp }
                }
            }
        }

        guard store.config.enabled, let gp = active?.extendedGamepad else { return }

        // Keyboard drag mode: R2 held + keyboard visible → left stick moves the
        // panel instead of the cursor. Short-circuits all mouse/scroll handling.
        if keyboard.visible && gp.rightTrigger.isPressed {
            let lx = CGFloat(gp.leftThumbstick.xAxis.value)
            let ly = CGFloat(gp.leftThumbstick.yAxis.value)
            let dead: CGFloat = 0.12
            if abs(lx) > dead || abs(ly) > dead {
                let speed: CGFloat = 9
                keyboard.windowMover?(lx * speed, ly * speed)
            }
            return
        }

        let useLeft = store.config.enableLeftStick
        let mouseStick: GCControllerDirectionPad
        let scrollStick: GCControllerDirectionPad?
        if useLeft {
            mouseStick  = store.config.swapSticks ? gp.rightThumbstick : gp.leftThumbstick
            scrollStick = store.config.swapSticks ? gp.leftThumbstick  : gp.rightThumbstick
        } else {
            mouseStick  = gp.rightThumbstick
            scrollStick = nil
        }

        var lx = CGFloat(mouseStick.xAxis.value)
        var ly = CGFloat(mouseStick.yAxis.value)
        if store.config.invertMouseX { lx = -lx }
        if store.config.invertMouseY { ly = -ly }

        let dead = CGFloat(store.config.deadzone)
        let curve = CGFloat(store.config.curve)
        var sens = 18.0 * CGFloat(store.config.pointerSpeed)
        if holdBoost { sens *= CGFloat(store.config.boostFactor) }
        if holdPrecision { sens *= CGFloat(store.config.precisionFactor) }

        func shape(_ v: CGFloat) -> CGFloat {
            let a = abs(v); if a <= dead { return 0 }
            let norm = (a - dead) / (1 - dead)
            return pow(norm, curve) * (v < 0 ? -1 : 1)
        }

        let targetVx = shape(lx) * sens
        let targetVy = -shape(ly) * sens
        let active = targetVx != 0 || targetVy != 0

        // Inertia: friction each frame when no input, blend toward target when input present.
        let retain = CGFloat(max(0.0, min(0.98, store.config.inertia)))
        if active {
            // blend quickly toward target velocity for crisp response
            vel.dx = vel.dx * 0.35 + targetVx * 0.65
            vel.dy = vel.dy * 0.35 + targetVy * 0.65
        } else {
            vel.dx *= retain
            vel.dy *= retain
            if abs(vel.dx) < 0.05 { vel.dx = 0 }
            if abs(vel.dy) < 0.05 { vel.dy = 0 }
        }

        if vel.dx != 0 || vel.dy != 0 {
            loc.x += vel.dx
            loc.y += vel.dy
            if let s = NSScreen.main {
                if loc.x < 0 { loc.x = 0; vel.dx = 0 }
                if loc.x > s.frame.width - 1 { loc.x = s.frame.width - 1; vel.dx = 0 }
                if loc.y < 0 { loc.y = 0; vel.dy = 0 }
                if loc.y > s.frame.height - 1 { loc.y = s.frame.height - 1; vel.dy = 0 }
            }
            let (moveType, moveBtn): (CGEventType, CGMouseButton) = {
                if leftDown   { return (.leftMouseDragged,  .left) }
                if rightDown  { return (.rightMouseDragged, .right) }
                if centerDown { return (.otherMouseDragged, .center) }
                return (.mouseMoved, .left)
            }()
            let ev = CGEvent(mouseEventSource: nil, mouseType: moveType,
                             mouseCursorPosition: loc, mouseButton: moveBtn)
            ev?.flags = []
            ev?.post(tap: .cghidEventTap)
        } else if !active {
            syncLoc()
        }

        if let s = scrollStick {
            var rx = s.xAxis.value
            var ry = s.yAxis.value
            if store.config.invertScrollX { rx = -rx }
            if store.config.invertScrollY { ry = -ry }
            let rdead = Float(dead)
            if abs(rx) > rdead || abs(ry) > rdead {
                let spd = Float(store.config.scrollSpeed) * 8
                let dy = Int32(-ry * spd), dx = Int32(rx * spd)
                CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                        wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)?.post(tap: .cghidEventTap)
            }
        }
    }

    func hidButton(_ name: String, pressed: Bool) {
        DispatchQueue.main.async { self.onBtn(name, pressed) }
    }

    private func onBtn(_ name: String, _ pressed: Bool) {
        let dedupeKey = "\(name)-\(pressed)"
        let now = Date()
        if let last = lastFire[dedupeKey], now.timeIntervalSince(last) < 0.05 { return }
        lastFire[dedupeKey] = now

        DispatchQueue.main.async {
            if pressed { self.store.pressedButtons.insert(name) }
            else       { self.store.pressedButtons.remove(name) }
        }

        // L1+R1 chord → defer single-shoulder actions by chordWindow so the chord
        // can intercept before the tab-switch fires. On release, swallow the event
        // if the chord already consumed this button or its deferred press is still pending.
        if name == "L1" || name == "R1" {
            let other = (name == "L1") ? "R1" : "L1"
            if pressed {
                let gp = active?.extendedGamepad
                let both = (gp?.leftShoulder.isPressed ?? false) && (gp?.rightShoulder.isPressed ?? false)
                if both {
                    shoulderPending[other]?.cancel()
                    shoulderPending[other] = nil
                    shoulderChorded.insert(name)
                    shoulderChorded.insert(other)
                    DispatchQueue.main.async { self.keyboard.toggle() }
                    haptics.tap(intensity: 0.9, sharpness: 0.95)
                    return
                }
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.shoulderPending[name] = nil
                    self.dispatchAction(name: name, pressed: true)
                }
                shoulderPending[name] = work
                DispatchQueue.main.asyncAfter(deadline: .now() + chordWindow, execute: work)
                return
            } else {
                if shoulderChorded.contains(name) {
                    shoulderChorded.remove(name)
                    return
                }
                if let w = shoulderPending[name] {
                    // Released inside the chord window — treat as a quick tap:
                    // cancel the deferred press, then fire press+release back-to-back.
                    w.cancel()
                    shoulderPending[name] = nil
                    dispatchAction(name: name, pressed: true)
                    dispatchAction(name: name, pressed: false)
                    return
                }
                // fall through to normal release
            }
        }

        dispatchAction(name: name, pressed: pressed)
    }

    private func dispatchAction(name: String, pressed: Bool) {
        let resolved: String = {
            if ["A","B","X","Y"].contains(name) {
                return store.config.faceSwap[name] ?? name
            }
            return name
        }()
        let act = store.config.buttons[resolved] ?? .none

        // Always allow toggleEnabled regardless of state
        if act == .toggleEnabled {
            if pressed { DispatchQueue.main.async { self.store.config.enabled.toggle() } }
            return
        }

        // Keyboard toggle works regardless of paused state
        if act == .keyboardToggle {
            if pressed {
                DispatchQueue.main.async { self.keyboard.toggle() }
                haptics.tap(intensity: 0.9, sharpness: 0.95)
            }
            return
        }

        // When on-screen keyboard visible, controller drives the keyboard — skip normal actions.
        if keyboard.visible {
            handleKeyboard(name, pressed: pressed)
            return
        }

        if pressed && store.config.enabled && act != .none {
            hud.push(button: resolved, action: act.label, kind: kind(for: resolved))
        }

        guard store.config.enabled else { return }

        if act == .holdPrecision {
            holdPrecision = pressed
            DispatchQueue.main.async { self.store.precisionActive = pressed }
            if pressed { haptics.tap(intensity: 0.75, sharpness: 0.35) }
            return
        }
        if act == .holdBoost {
            holdBoost = pressed
            DispatchQueue.main.async { self.store.boostActive = pressed }
            if pressed { haptics.tap(intensity: 1.0, sharpness: 1.0) }
            return
        }
        if let modFlag = modifierFlag(for: act) {
            if pressed { heldMods.insert(modFlag) }
            else       { heldMods.remove(modFlag) }
            if pressed { haptics.tap(intensity: 0.9, sharpness: 1.0) }
            return
        }

        if pressed {
            perform(act, down: true, for: resolved)
            heldAction[name] = (act, resolved)
            if store.config.keyRepeatEnabled && act.repeatable {
                repeats[name] = (act, resolved, Date().addingTimeInterval(store.config.keyRepeatDelay))
            }
        } else {
            if let h = heldAction[name] { perform(h.action, down: false, for: h.resolved) }
            heldAction[name] = nil
            repeats[name] = nil
        }
    }

    private func handleKeyboard(_ name: String, pressed: Bool) {
        // Resolve face buttons through faceSwap so the on-screen keyboard obeys the same remap.
        let resolved: String = {
            if ["A","B","X","Y"].contains(name) {
                return store.config.faceSwap[name] ?? name
            }
            return name
        }()
        // Shift is a hold modifier (L2); reflect on both press and release
        if resolved == "L2" {
            DispatchQueue.main.async { self.keyboard.shift = pressed }
            return
        }
        if !pressed {
            kbRepeats[resolved] = nil
            return
        }
        fireKb(resolved)
        // MENU toggles the panel — don't repeat it
        if resolved != "MENU" {
            kbRepeats[resolved] = Date().addingTimeInterval(store.config.keyRepeatDelay)
        }
    }

    private func fireKb(_ name: String) {
        DispatchQueue.main.async {
            switch name {
            case "UP":
                self.keyboard.move(-1, 0)
                self.haptics.tap(intensity: 0.55, sharpness: 1.0)
            case "DOWN":
                self.keyboard.move(1, 0)
                self.haptics.tap(intensity: 0.55, sharpness: 1.0)
            case "LEFT":
                self.keyboard.move(0, -1)
                self.haptics.tap(intensity: 0.55, sharpness: 1.0)
            case "RIGHT":
                self.keyboard.move(0, 1)
                self.haptics.tap(intensity: 0.55, sharpness: 1.0)
            case "L1":
                self.keyboard.move(0, -5)
                self.haptics.tap(intensity: 0.8, sharpness: 0.75)
            case "R1":
                self.keyboard.move(0, 5)
                self.haptics.tap(intensity: 0.8, sharpness: 0.75)
            case "A":
                let label = self.keyboard.selectedLabel()
                self.keyboard.typeSelected()
                self.hud.push(button: "A", action: "type \(label)", kind: .face)
                self.haptics.tap(intensity: 0.9, sharpness: 1.0)
            case "B":
                self.keyboard.backspace()
                self.hud.push(button: "B", action: "⌫", kind: .face)
                self.haptics.tap(intensity: 0.95, sharpness: 0.5)
            case "X":
                self.keyboard.space()
                self.hud.push(button: "X", action: "␣", kind: .face)
                self.haptics.tap(intensity: 0.75, sharpness: 0.4)
            case "Y":
                self.keyboard.returnKey()
                self.hud.push(button: "Y", action: "↩", kind: .face)
                self.haptics.tap(intensity: 1.0, sharpness: 0.7)
            case "MENU":
                self.keyboard.toggle()
                self.haptics.pulseDown()
            default: break
            }
        }
    }

    private func kind(for name: String) -> HUDEvent.Kind {
        switch name {
        case "A","B","X","Y": return .face
        case "UP","DOWN","LEFT","RIGHT": return .dpad
        case "L1","R1","L2","R2","L3","R3": return .shoulder
        default: return .system
        }
    }

    private func releaseAll() {
        for (_, h) in heldAction { perform(h.action, down: false, for: h.resolved) }
        heldAction.removeAll()
        repeats.removeAll()
        holdBoost = false
        holdPrecision = false
        DispatchQueue.main.async {
            self.store.precisionActive = false
            self.store.boostActive = false
        }
    }

    private func perform(_ a: ButtonAction, down: Bool, for name: String = "") {
        switch a {
        case .none: break
        case .leftClick: mouseBtn(.left, down)
        case .rightClick: mouseBtn(.right, down)
        case .middleClick: mouseBtn(.center, down)
        case .arrowUp: key(126, down)
        case .arrowDown: key(125, down)
        case .arrowLeft: key(123, down)
        case .arrowRight: key(124, down)
        case .space: key(49, down)
        case .enter: key(36, down)
        case .escape: key(53, down)
        case .tab: key(48, down)
        case .forwardDelete: key(117, down)
        case .backspace: key(51, down)
        case .cmdTab: keyMod(48, .maskCommand, down)
        case .cmdShiftTab: keyMod(48, [.maskCommand, .maskShift], down)
        case .cmdReturn: keyMod(36, .maskCommand, down)
        case .cmdEscape: keyMod(53, .maskCommand, down)
        case .prevTab: keyMod(48, [.maskControl, .maskShift], down)
        case .nextTab: keyMod(48, .maskControl, down)
        case .copy: keyMod(8, .maskCommand, down)
        case .paste: keyMod(9, .maskCommand, down)
        case .cut: keyMod(7, .maskCommand, down)
        case .undo: keyMod(6, .maskCommand, down)
        case .redo: keyMod(6, [.maskCommand, .maskShift], down)
        case .missionControl: keyMod(126, .maskControl, down)
        case .appExpose: keyMod(125, .maskControl, down)
        case .desktopLeft: keyMod(123, .maskControl, down)
        case .desktopRight: keyMod(124, .maskControl, down)
        case .spotlight: keyMod(49, .maskCommand, down)
        case .launchpad: key(118, down)
        case .volumeUp: media(0, down)
        case .volumeDown: media(1, down)
        case .volumeMute: media(7, down)
        case .brightnessUp: media(2, down)
        case .brightnessDown: media(3, down)
        case .playPause: media(16, down)
        case .nextTrack: media(17, down)
        case .prevTrack: media(18, down)
        case .scrollUp: if down { scrollTick(+1) }
        case .scrollDown: if down { scrollTick(-1) }
        case .custom:
            if let ck = store.config.customKeys[name] {
                keyMod(CGKeyCode(ck.keyCode), CGEventFlags(rawValue: UInt64(ck.modifiers)), down)
            }
        case .keyboardToggle, .toggleEnabled, .holdPrecision, .holdBoost,
             .holdCtrl, .holdShift, .holdOption, .holdCmd: break
        }
    }

    private func scrollTick(_ sign: Int32) {
        let mag = Int32(max(4, 30 * store.config.scrollSpeed))
        let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                        wheelCount: 1, wheel1: sign * mag, wheel2: 0, wheel3: 0)
        e?.flags = []
        e?.post(tap: .cghidEventTap)
    }

    private func mouseBtn(_ b: CGMouseButton, _ down: Bool) {
        let t: CGEventType
        switch (b, down) {
        case (.left, true):    t = .leftMouseDown;   leftDown = true
        case (.left, false):   t = .leftMouseUp;     leftDown = false
        case (.right, true):   t = .rightMouseDown;  rightDown = true
        case (.right, false):  t = .rightMouseUp;    rightDown = false
        case (.center, true):  t = .otherMouseDown;  centerDown = true
        case (.center, false): t = .otherMouseUp;    centerDown = false
        default: return
        }
        let e = CGEvent(mouseEventSource: nil, mouseType: t,
                        mouseCursorPosition: loc, mouseButton: b)
        e?.flags = heldMods
        e?.setIntegerValueField(.mouseEventClickState, value: 1)
        e?.post(tap: .cghidEventTap)
    }

    private func key(_ code: CGKeyCode, _ down: Bool) {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        // Don't forcibly clear flags here — let keyboard events inherit combined
        // session state. Overlay heldMods only when a hold-modifier is active.
        if !heldMods.isEmpty { e?.flags = heldMods }
        e?.post(tap: .cghidEventTap)
    }

    private func keyMod(_ code: CGKeyCode, _ flags: CGEventFlags, _ down: Bool) {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        e?.flags = flags.union(heldMods)
        e?.post(tap: .cghidEventTap)
    }


    private func modifierFlag(for a: ButtonAction) -> CGEventFlags? {
        switch a {
        case .holdCtrl:   return .maskControl
        case .holdShift:  return .maskShift
        case .holdOption: return .maskAlternate
        case .holdCmd:    return .maskCommand
        default: return nil
        }
    }

    private func media(_ keyType: Int, _ down: Bool) {
        let flag = down ? 0xA00 : 0xB00
        let data1 = (keyType << 16) | flag
        let ev = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flag)),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1, data2: -1)
        ev?.cgEvent?.post(tap: .cghidEventTap)
    }
}

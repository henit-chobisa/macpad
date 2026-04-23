import Foundation
import Combine
import CoreGraphics

enum ButtonAction: String, Codable, CaseIterable, Identifiable {
    case none
    case leftClick, rightClick, middleClick
    case arrowUp, arrowDown, arrowLeft, arrowRight
    case space, enter, escape, tab, forwardDelete, backspace
    case cmdTab, cmdShiftTab, cmdReturn, cmdEscape
    case prevTab, nextTab
    case copy, paste, cut, undo, redo
    case missionControl, appExpose, spotlight, desktopLeft, desktopRight, launchpad
    case volumeUp, volumeDown, volumeMute
    case playPause, nextTrack, prevTrack
    case brightnessUp, brightnessDown
    case scrollUp, scrollDown
    case custom
    case keyboardToggle
    case toggleEnabled
    case holdPrecision
    case holdBoost
    case holdCtrl
    case holdShift
    case holdOption
    case holdCmd

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "— Nothing —"
        case .leftClick: return "Left Click"
        case .rightClick: return "Right Click"
        case .middleClick: return "Middle Click"
        case .arrowUp: return "Arrow ↑"
        case .arrowDown: return "Arrow ↓"
        case .arrowLeft: return "Arrow ←"
        case .arrowRight: return "Arrow →"
        case .space: return "Space"
        case .enter: return "Return"
        case .escape: return "Escape"
        case .tab: return "Tab"
        case .forwardDelete: return "Forward Delete"
        case .backspace: return "Backspace"
        case .cmdTab: return "⌘ Tab"
        case .cmdShiftTab: return "⌘ ⇧ Tab"
        case .cmdReturn: return "⌘ Return"
        case .cmdEscape: return "⌘ Escape"
        case .prevTab: return "⌃ ⇧ Tab (Prev Tab)"
        case .nextTab: return "⌃ Tab (Next Tab)"
        case .copy: return "Copy (⌘C)"
        case .paste: return "Paste (⌘V)"
        case .cut: return "Cut (⌘X)"
        case .undo: return "Undo (⌘Z)"
        case .redo: return "Redo (⌘⇧Z)"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .spotlight: return "Spotlight"
        case .desktopLeft: return "Desktop ←"
        case .desktopRight: return "Desktop →"
        case .launchpad: return "Launchpad"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .volumeMute: return "Mute"
        case .playPause: return "Play / Pause"
        case .nextTrack: return "Next Track"
        case .prevTrack: return "Previous Track"
        case .brightnessUp: return "Brightness Up"
        case .brightnessDown: return "Brightness Down"
        case .scrollUp: return "Scroll ↑"
        case .scrollDown: return "Scroll ↓"
        case .custom: return "Custom Key…"
        case .keyboardToggle: return "Toggle On-screen Keyboard"
        case .toggleEnabled: return "Toggle macpad On/Off"
        case .holdPrecision: return "Hold — Precision"
        case .holdBoost: return "Hold — Boost"
        case .holdCtrl: return "Hold — Control (⌃)"
        case .holdShift: return "Hold — Shift (⇧)"
        case .holdOption: return "Hold — Option (⌥)"
        case .holdCmd: return "Hold — Command (⌘)"
        }
    }

    var repeatable: Bool {
        switch self {
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight,
             .space, .enter, .backspace, .forwardDelete, .tab,
             .prevTab, .nextTab,
             .volumeUp, .volumeDown, .brightnessUp, .brightnessDown,
             .scrollUp, .scrollDown, .custom:
            return true
        default: return false
        }
    }
}

struct CustomKey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt  // NSEvent.ModifierFlags rawValue masked to shift/ctrl/opt/cmd

    var display: String {
        var s = ""
        if modifiers & 0x040000 != 0 { s += "⌃" }
        if modifiers & 0x080000 != 0 { s += "⌥" }
        if modifiers & 0x020000 != 0 { s += "⇧" }
        if modifiers & 0x100000 != 0 { s += "⌘" }
        s += KeyNames.name(for: keyCode)
        return s
    }
}

enum KeyNames {
    static func name(for code: UInt16) -> String {
        switch code {
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
        case 17: return "T"; case 18: return "1"; case 19: return "2"; case 20: return "3"
        case 21: return "4"; case 22: return "6"; case 23: return "5"; case 24: return "="
        case 25: return "9"; case 26: return "7"; case 27: return "-"; case 28: return "8"
        case 29: return "0"; case 30: return "]"; case 31: return "O"; case 32: return "U"
        case 33: return "["; case 34: return "I"; case 35: return "P"; case 36: return "↩"
        case 37: return "L"; case 38: return "J"; case 39: return "'"; case 40: return "K"
        case 41: return ";"; case 42: return "\\"; case 43: return ","; case 44: return "/"
        case 45: return "N"; case 46: return "M"; case 47: return "."; case 48: return "⇥"
        case 49: return "␣"; case 50: return "`"; case 51: return "⌫"; case 53: return "⎋"
        case 117: return "⌦"; case 123: return "←"; case 124: return "→"
        case 125: return "↓"; case 126: return "↑"
        case 122: return "F1"; case 120: return "F2"; case 99: return "F3"; case 118: return "F4"
        case 96: return "F5"; case 97: return "F6"; case 98: return "F7"; case 100: return "F8"
        case 101: return "F9"; case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        default: return "#\(code)"
        }
    }
}

struct Config: Codable, Equatable {
    var enabled: Bool = true
    var pointerSpeed: Double = 1.0
    var scrollSpeed: Double = 1.0
    var deadzone: Double = 0.15
    var curve: Double = 2.0
    var swapSticks: Bool = false
    var invertMouseX: Bool = false
    var invertMouseY: Bool = false
    var invertScrollX: Bool = false
    var invertScrollY: Bool = false
    var keyRepeatEnabled: Bool = true
    var keyRepeatDelay: Double = 0.4
    var keyRepeatRate: Double = 20
    var inertia: Double = 0.88  // per-frame velocity retention, 0=no glide, 0.98=lots of glide
    var enableLeftStick: Bool = false
    var showHUD: Bool = true
    var hapticsEnabled: Bool = true
    var precisionFactor: Double = 0.35  // sensitivity multiplier while holdPrecision held
    var boostFactor: Double = 2.5       // sensitivity multiplier while holdBoost held
    var buttons: [String: ButtonAction] = defaultMap
    var faceSwap: [String: String] = defaultFaceSwap
    var customKeys: [String: CustomKey] = [:]

    static let defaultMap: [String: ButtonAction] = [
        "A": .leftClick,
        "B": .rightClick,
        "X": .space,
        "Y": .cmdReturn,
        "UP": .scrollUp,
        "DOWN": .scrollDown,
        "LEFT": .arrowLeft,
        "RIGHT": .arrowRight,
        "L1": .prevTab,
        "R1": .nextTab,
        "L2": .holdBoost,
        "R2": .holdPrecision,
        "L3": .leftClick,
        "R3": .rightClick,
        "OPT": .escape,
        "MENU": .cmdTab,
        "HOME": .toggleEnabled,
        "SHARE": .keyboardToggle,
        "TOUCHPAD": .toggleEnabled,
    ]

    static let defaultFaceSwap: [String: String] = [
        "A": "A", "B": "B", "X": "X", "Y": "Y",
    ]
}

final class Store: ObservableObject {
    @Published var config: Config
    @Published var controllerName: String?
    @Published var pressedButtons: Set<String> = []
    @Published var leftStick: CGPoint = .zero
    @Published var rightStick: CGPoint = .zero
    @Published var precisionActive: Bool = false
    @Published var boostActive: Bool = false

    private let url: URL
    private var saveCancellable: AnyCancellable?

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("macpad", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.url = base.appendingPathComponent("config.json")
        self.config = Store.load(from: url) ?? Config()
        self.saveCancellable = $config
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] cfg in self?.save(cfg) }
    }

    private func save(_ cfg: Config) {
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        if let d = try? enc.encode(cfg) { try? d.write(to: url, options: .atomic) }
    }

    private static func load(from url: URL) -> Config? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        if let c = try? JSONDecoder().decode(Config.self, from: d) { return c }
        // Merge defaults for any missing keys, then retry decode. Keeps old saved configs valid when new fields are added.
        guard var loaded = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let defData = try? JSONEncoder().encode(Config()),
              let defDict = (try? JSONSerialization.jsonObject(with: defData)) as? [String: Any]
        else { return nil }
        for (k, v) in defDict where loaded[k] == nil { loaded[k] = v }
        guard let merged = try? JSONSerialization.data(withJSONObject: loaded) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: merged)
    }
}

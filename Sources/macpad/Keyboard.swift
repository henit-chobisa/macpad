import AppKit
import SwiftUI
import Combine
import CoreGraphics

final class KeyboardManager: ObservableObject {
    @Published var visible = false
    @Published var row = 0
    @Published var col = 0
    @Published var shift = false
    // Wired up by KeyboardHost once the panel exists. Pad uses this to drag
    // the window from a gamepad button without needing a reference to AppKit.
    var windowMover: ((CGFloat, CGFloat) -> Void)?

    static let rows: [[String]] = [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l",";"],
        ["z","x","c","v","b","n","m",",",".","/"],
    ]
    var cols: Int { Self.rows[0].count }
    var rowCount: Int { Self.rows.count }

    func toggle() {
        visible.toggle()
        if visible { row = 0; col = 0 }
    }

    func move(_ dr: Int, _ dc: Int) {
        row = max(0, min(rowCount - 1, row + dr))
        col = max(0, min(cols - 1, col + dc))
    }

    func typeSelected() {
        let raw = Self.rows[row][col]
        guard let code = Self.keyCodes[raw] else { return }
        let flags: CGEventFlags = shift ? .maskShift : []
        keyTapWithFlags(code, flags)
    }

    func selectedLabel() -> String {
        let raw = Self.rows[row][col]
        return shift ? raw.uppercased() : raw
    }

    func space()     { keyTap(49) }
    func returnKey() { keyTap(36) }
    func backspace() { keyTap(51) }

    // Physical virtualKey mapping for each on-screen key. Using real keycodes
    // (vs unicode override with virtualKey 0) makes synthetic events behave like
    // a real keyboard, so games and apps that ignore keyboardSetUnicodeString
    // still receive the input.
    private static let keyCodes: [String: CGKeyCode] = [
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "q": 12, "w": 13, "e": 14, "r": 15, "t": 17,
        "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "g": 5,
        "h": 4,  "j": 38, "k": 40, "l": 37, ";": 41,
        "z": 6,  "x": 7,  "c": 8,  "v": 9,  "b": 11,
        "n": 45, "m": 46, ",": 43, ".": 47, "/": 44,
    ]

    private func keyTap(_ code: CGKeyCode) {
        keyTapWithFlags(code, [])
    }

    private func keyTapWithFlags(_ code: CGKeyCode, _ flags: CGEventFlags) {
        if let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true) {
            d.flags = flags
            d.post(tap: .cghidEventTap)
        }
        if let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
            u.flags = flags
            u.post(tap: .cghidEventTap)
        }
    }
}

// NSHostingView subclass that lets the window intercept mouse drags. SwiftUI
// views normally consume click events, which blocks NSPanel's
// isMovableByWindowBackground — this override opts the whole content area
// back into window-drag handling.
private final class DragHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class KeyboardHost {
    let manager: KeyboardManager
    private var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    init(manager: KeyboardManager) {
        self.manager = manager
        manager.$visible
            .removeDuplicates()
            .sink { [weak self] v in self?.setVisible(v) }
            .store(in: &cancellables)
    }

    private func setVisible(_ v: Bool) {
        if v {
            if window == nil {
                let w = Self.makeWindow(manager: manager)
                window = w
                manager.windowMover = { [weak w] dx, dy in
                    guard let w else { return }
                    var f = w.frame
                    f.origin.x += dx
                    f.origin.y += dy
                    w.setFrame(f, display: true)
                }
            }
            window?.orderFrontRegardless()
        } else {
            window?.orderOut(nil)
        }
    }

    private static func makeWindow(manager: KeyboardManager) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        let host = DragHostingView(rootView: KeyboardPanelView(manager: manager))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host

        if let s = NSScreen.main {
            let r = panel.frame
            let x = s.frame.midX - r.width / 2
            let y = s.frame.minY + 120
            panel.setFrame(NSRect(x: x, y: y, width: r.width, height: r.height), display: false)
        }
        return panel
    }
}

private struct KeyboardPanelView: View {
    @ObservedObject var manager: KeyboardManager

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    contentStack
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .glassEffect(
                            .regular.tint(Color.white.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                }
            } else {
                contentStack
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(fallbackBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 40, y: 22)
    }

    private var contentStack: some View {
        VStack(spacing: 8) {
            ForEach(0..<manager.rowCount, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<manager.cols, id: \.self) { c in
                        cell(r: r, c: c)
                    }
                }
            }
            footer.padding(.top, 12)
        }
    }

    private var fallbackBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.16),
                    Color(red: 0.06, green: 0.07, blue: 0.10),
                ],
                startPoint: .top, endPoint: .bottom
            )
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            hint("A", "type")
            hint("B", "⌫")
            hint("X", "␣")
            hint("Y", "↩")
            hint("L2", "shift", accent: manager.shift)
            hint("L1/R1", "±5")
        }
    }

    private func cell(r: Int, c: Int) -> some View {
        let raw = KeyboardManager.rows[r][c]
        let display = manager.shift ? raw.uppercased() : raw
        let selected = manager.row == r && manager.col == c
        return KeyCap(label: display, selected: selected)
    }

    private func hint(_ k: String, _ a: String, accent: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(k)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(0.6)
                .foregroundStyle(accent ? Color.black : Color.white.opacity(0.92))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent ? Color(red: 0.52, green: 0.78, blue: 1.0) : Color.white.opacity(0.10))
                )
            Text(a)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

private struct KeyCap: View {
    let label: String
    let selected: Bool

    // Soft blue accent — muted, not neon. Pairs with dark panel.
    private static let accent = Color(red: 0.36, green: 0.58, blue: 0.98)

    var body: some View {
        ZStack {
            // base cap
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    selected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Self.accent, Self.accent.opacity(0.78)],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom))
                )
            // inner top-edge highlight — gives subtle keycap depth
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(selected ? 0.55 : 0.18),
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            // bottom inner shadow for depth (idle only)
            if !selected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.18)],
                            startPoint: .center, endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
            Text(label)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.88))
                .shadow(color: .black.opacity(selected ? 0.35 : 0.25), radius: 1, y: 1)
        }
        .frame(width: 48, height: 46)
        .scaleEffect(selected ? 1.12 : 1.0)
        .shadow(color: selected ? Self.accent.opacity(0.55) : Color.black.opacity(0.35),
                radius: selected ? 14 : 4, y: selected ? 4 : 2)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
    }
}

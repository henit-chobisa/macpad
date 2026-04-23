import SwiftUI
import AppKit
import Combine

struct HUDEvent: Identifiable, Equatable {
    let id = UUID()
    let button: String
    let action: String
    let kind: Kind
    var at: Date
    var count: Int = 1

    enum Kind: Equatable { case face, dpad, shoulder, system }
}

final class HUDManager: ObservableObject {
    @Published var events: [HUDEvent] = []
    private var gc: Timer?
    private let lifetime: TimeInterval = 1.8

    init() {
        gc = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.purge()
        }
    }

    func push(button: String, action: String, kind: HUDEvent.Kind) {
        DispatchQueue.main.async {
            // Dedupe rapid repeats of identical events — bump count + refresh timestamp
            // instead of spawning a new pill. Keeps the HUD calm during key repeat / mashing.
            let now = Date()
            if let last = self.events.last,
               last.button == button,
               last.action == action,
               now.timeIntervalSince(last.at) < 0.8 {
                var updated = last
                updated.count += 1
                updated.at = now
                self.events[self.events.count - 1] = updated
                return
            }
            self.events.append(HUDEvent(button: button, action: action, kind: kind, at: now))
            if self.events.count > 8 {
                self.events.removeFirst(self.events.count - 8)
            }
        }
    }

    private func purge() {
        let cutoff = Date().addingTimeInterval(-lifetime)
        if events.first(where: { $0.at < cutoff }) != nil {
            events.removeAll { $0.at < cutoff }
        }
    }
}

final class HUDWindow: NSWindow {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: 120),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovable = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HUD {
    let manager: HUDManager
    let window: HUDWindow
    private var cancellables = Set<AnyCancellable>()

    init(manager: HUDManager, store: Store) {
        self.manager = manager
        self.window = HUDWindow()
        let host = NSHostingView(rootView: HUDView(manager: manager, store: store))
        host.frame = NSRect(x: 0, y: 0, width: 800, height: 120)
        window.contentView = host
        reposition()

        if store.config.showHUD { window.orderFrontRegardless() }

        store.$config
            .map(\.showHUD)
            .removeDuplicates()
            .sink { [weak self] on in
                guard let s = self else { return }
                if on { s.window.orderFrontRegardless() } else { s.window.orderOut(nil) }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.reposition()
        }
    }

    private func reposition() {
        guard let s = NSScreen.main else { return }
        let f = window.frame
        let x = s.visibleFrame.midX - f.width / 2
        let y = s.visibleFrame.minY + 70
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct HUDView: View {
    @ObservedObject var manager: HUDManager
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            if store.precisionActive {
                ModeChip(label: "PRECISION", color: .cyan)
                    .transition(.scale.combined(with: .opacity))
            }
            if store.boostActive {
                ModeChip(label: "BOOST", color: .orange)
                    .transition(.scale.combined(with: .opacity))
            }
            ForEach(manager.events) { ev in
                HUDPill(event: ev)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: manager.events)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: store.precisionActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: store.boostActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ModeChip: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.s6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
                .shadow(color: color.opacity(0.9), radius: 4)
            Text(label)
                .font(Theme.display(10.5, .heavy))
                .tracking(1.4)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Theme.s12)
        .padding(.vertical, Theme.s6)
        .elevatedPill(tint: color, intensity: 0.9)
    }
}

struct HUDPill: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: Theme.s8) {
            ButtonBadge(name: event.button, kind: event.kind, size: 30)
            Text(event.action)
                .font(Theme.display(13, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
            if event.count > 1 {
                Text("×\(event.count)")
                    .font(Theme.mono(10.5, .heavy))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, Theme.s6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.white.opacity(0.18))
                    )
                    .contentTransition(.numericText())
                    .animation(Theme.springFast, value: event.count)
            }
        }
        .padding(.leading, Theme.s6)
        .padding(.trailing, Theme.s12)
        .padding(.vertical, Theme.s6)
        .elevatedPill(tint: tint(for: event.kind))
    }

    private func tint(for kind: HUDEvent.Kind) -> Color {
        switch kind {
        case .face:     return Theme.faceAccent
        case .dpad:     return Theme.dpadAccent
        case .shoulder: return Theme.shoulderAccent
        case .system:   return Theme.systemAccent
        }
    }
}

struct ButtonBadge: View {
    let name: String
    let kind: HUDEvent.Kind
    var size: CGFloat = 22

    var body: some View {
        let (sym, text, color) = visual()
        ZStack {
            // Primary color fill with a directional gradient → gives the button depth.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // Inner highlight along the top edge — fakes specular.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            if let sym {
                Image(systemName: sym)
                    .font(.system(size: size * 0.52, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            } else {
                Text(text)
                    .font(Theme.display(size * 0.48, .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.55), radius: 6, y: 2)
    }

    private func visual() -> (String?, String, Color) {
        switch name {
        case "A":     return (nil, "A", Color(red: 0.98, green: 0.28, blue: 0.38))
        case "B":     return (nil, "B", Color(red: 1.00, green: 0.62, blue: 0.24))
        case "X":     return (nil, "X", Color(red: 0.30, green: 0.62, blue: 1.00))
        case "Y":     return (nil, "Y", Color(red: 0.36, green: 0.82, blue: 0.54))
        case "UP":    return ("arrow.up",    "↑", Theme.dpadAccent)
        case "DOWN":  return ("arrow.down",  "↓", Theme.dpadAccent)
        case "LEFT":  return ("arrow.left",  "←", Theme.dpadAccent)
        case "RIGHT": return ("arrow.right", "→", Theme.dpadAccent)
        case "L1":    return (nil, "L", Theme.shoulderAccent)
        case "R1":    return (nil, "R", Theme.shoulderAccent)
        case "L2":    return (nil, "ZL", Theme.shoulderAccent)
        case "R2":    return (nil, "ZR", Theme.shoulderAccent)
        case "OPT":   return ("minus", "−", Theme.systemAccent)
        case "MENU":  return ("plus",  "+", Theme.systemAccent)
        default:      return (nil, name, Color.secondary)
        }
    }
}

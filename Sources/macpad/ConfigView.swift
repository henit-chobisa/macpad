import SwiftUI
import AppKit

// Legacy alias kept for any external references; new code should use GlassMaterial.
struct VisualEffectBG: View {
    var body: some View { GlassMaterial(material: .sidebar) }
}

enum Tab: String, CaseIterable, Identifiable {
    case general, mapping, keyboard, overlay, feedback

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general:  return "Sticks"
        case .mapping:  return "Buttons"
        case .keyboard: return "Keyboard"
        case .overlay:  return "Overlay"
        case .feedback: return "Feedback"
        }
    }
    var icon: String {
        switch self {
        case .general:  return "dot.circle.and.hand.point.up.left.fill"
        case .mapping:  return "square.grid.3x3.fill"
        case .keyboard: return "keyboard"
        case .overlay:  return "rectangle.on.rectangle"
        case .feedback: return "waveform"
        }
    }
}

struct ConfigView: View {
    @ObservedObject var store: Store
    @State private var tab: Tab = .general
    @Namespace private var navNS

    var body: some View {
        ZStack {
            GlassMaterial(material: .sidebar)
            // Subtle directional wash gives the popover a sense of light.
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                hero
                    .padding(.horizontal, Theme.s20)
                    .padding(.top, Theme.s16)
                    .padding(.bottom, Theme.s12)
                navBar
                    .padding(.horizontal, Theme.s16)
                GlassDivider()
                    .padding(.top, Theme.s8)
                ScrollView {
                    Group {
                        switch tab {
                        case .general:  generalPage
                        case .mapping:  mappingPage
                        case .keyboard: keyboardPage
                        case .overlay:  overlayPage
                        case .feedback: feedbackPage
                        }
                    }
                    .id(tab)
                    .transition(.opacity)
                    .padding(.horizontal, Theme.s20)
                    .padding(.top, Theme.s16)
                    .padding(.bottom, Theme.s20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                GlassDivider()
                footer
                    .padding(.horizontal, Theme.s20)
                    .padding(.vertical, Theme.s12)
            }
        }
        .frame(width: 510, height: 620)
    }

    // MARK: hero

    private var hero: some View {
        HStack(spacing: Theme.s12) {
            AppMark()
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.s8) {
                    Text("macpad")
                        .font(Theme.display(20, .bold))
                        .foregroundStyle(.primary)
                    StatusDot(active: store.config.enabled, connected: store.controllerName != nil)
                }
                Text(statusText)
                    .font(Theme.label(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $store.config.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private var statusText: String {
        guard let c = store.controllerName else { return "Waiting for controller" }
        return store.config.enabled ? "\(c) · active" : "\(c) · paused"
    }

    // MARK: nav

    private var navBar: some View {
        HStack(spacing: Theme.s2) {
            ForEach(Tab.allCases) { t in
                NavPill(tab: t, selected: tab == t, ns: navNS) {
                    withAnimation(Theme.springFast) { tab = t }
                }
            }
            Spacer()
        }
    }

    // MARK: pages

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: Theme.s16) {
            SectionCard(
                icon: "arrow.triangle.2.circlepath",
                title: "Face Swap",
                tint: Theme.faceAccent,
                trailing: AnyView(
                    MicroButton(label: "Reset") {
                        withAnimation(Theme.springFast) {
                            store.config.faceSwap = Config.defaultFaceSwap
                        }
                    }
                )
            ) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.s8),
                                    GridItem(.flexible(), spacing: Theme.s8)],
                          spacing: Theme.s8) {
                    QuickMap(key: "A", target: faceBinding("A"), pressed: store.pressedButtons.contains("A"))
                    QuickMap(key: "B", target: faceBinding("B"), pressed: store.pressedButtons.contains("B"))
                    QuickMap(key: "X", target: faceBinding("X"), pressed: store.pressedButtons.contains("X"))
                    QuickMap(key: "Y", target: faceBinding("Y"), pressed: store.pressedButtons.contains("Y"))
                }
            }

            // Cursor split into two side-by-side tiles — breaks up the
            // vertical slider monotony and makes the page read like a dashboard.
            HStack(alignment: .top, spacing: Theme.s12) {
                SectionCard(icon: "cursorarrow.motionlines", title: "Speed", tint: Theme.systemAccent) {
                    VStack(spacing: Theme.s10) {
                        MinimalSlider(title: "Pointer",  value: $store.config.pointerSpeed, range: 0.25...3.0, fmt: "%.2fx")
                        MinimalSlider(title: "Scroll",   value: $store.config.scrollSpeed,  range: 0.25...3.0, fmt: "%.2fx")
                        MinimalSlider(title: "Deadzone", value: $store.config.deadzone,     range: 0.02...0.4, fmt: "%.2f")
                    }
                }
                SectionCard(icon: "waveform.path", title: "Feel", tint: Theme.dpadAccent) {
                    VStack(spacing: Theme.s10) {
                        MinimalSlider(title: "Accel", value: $store.config.curve,   range: 1.0...3.5,  fmt: "%.2f")
                        MinimalSlider(title: "Glide", value: $store.config.inertia, range: 0.0...0.96, fmt: "%.2f")
                    }
                }
            }

            SectionCard(icon: "dpad.fill", title: "Sticks", tint: Theme.dpadAccent) {
                VStack(spacing: Theme.s12) {
                    MinimalToggle(title: "Enable left stick",
                                  subtitle: "Left = mouse, right = scroll. Off by default (some dongles strip left-stick data).",
                                  isOn: $store.config.enableLeftStick)
                    Group {
                        MinimalToggle(title: "Swap left and right sticks", isOn: $store.config.swapSticks)
                        MinimalToggle(title: "Invert scroll X", isOn: $store.config.invertScrollX)
                        MinimalToggle(title: "Invert scroll Y", isOn: $store.config.invertScrollY)
                    }
                    .disabled(!store.config.enableLeftStick)
                    .opacity(store.config.enableLeftStick ? 1.0 : 0.35)
                    MinimalToggle(title: "Invert mouse X", isOn: $store.config.invertMouseX)
                    MinimalToggle(title: "Invert mouse Y", isOn: $store.config.invertMouseY)
                }
            }

            SectionCard(icon: "slider.horizontal.3", title: "Precision & Boost", tint: .cyan) {
                VStack(spacing: Theme.s12) {
                    MinimalSlider(title: "Precision factor", value: $store.config.precisionFactor,
                                  range: 0.1...0.9, fmt: "%.2fx")
                    MinimalSlider(title: "Boost factor", value: $store.config.boostFactor,
                                  range: 1.2...4.0, fmt: "%.2fx")
                }
            }
        }
    }

    private var mappingPage: some View {
        MappingPage(store: store)
    }

    private var keyboardPage: some View {
        VStack(alignment: .leading, spacing: Theme.s16) {
            SectionCard(icon: "keyboard", title: "On-screen keyboard", tint: Theme.faceAccent) {
                VStack(alignment: .leading, spacing: Theme.s8) {
                    Text("Open the controller keyboard with any button mapped to ‘Toggle On-screen Keyboard’ (default: Share). Hold a key to auto-repeat.")
                        .font(Theme.label(11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(1.5)
                    HStack(spacing: Theme.s10) {
                        inlineHint("D-Pad", "Nav")
                        inlineHint("L1/R1", "±5")
                        inlineHint("A", "Type")
                        inlineHint("B", "⌫")
                        inlineHint("X", "␣")
                        inlineHint("Y", "↩")
                    }
                }
            }
            SectionCard(icon: "repeat", title: "Key repeat", tint: Theme.dpadAccent) {
                VStack(spacing: Theme.s12) {
                    MinimalToggle(
                        title: "Enable key repeat",
                        subtitle: "Arrows, tabs, volume, brightness, on-screen kb.",
                        isOn: $store.config.keyRepeatEnabled
                    )
                    Group {
                        MinimalSlider(title: "Initial delay", value: $store.config.keyRepeatDelay,
                                      range: 0.1...1.0, fmt: "%.2fs")
                        MinimalSlider(title: "Repeat rate", value: $store.config.keyRepeatRate,
                                      range: 5...40, fmt: "%.0f Hz")
                    }
                    .disabled(!store.config.keyRepeatEnabled)
                    .opacity(store.config.keyRepeatEnabled ? 1.0 : 0.35)
                }
            }
        }
    }

    private var overlayPage: some View {
        VStack(alignment: .leading, spacing: Theme.s16) {
            SectionCard(icon: "rectangle.on.rectangle", title: "HUD overlay", tint: Theme.shoulderAccent) {
                MinimalToggle(
                    title: "Show key overlay",
                    subtitle: "Floating pill at bottom of screen when buttons are pressed.",
                    isOn: $store.config.showHUD
                )
            }
        }
    }

    private var feedbackPage: some View {
        VStack(alignment: .leading, spacing: Theme.s16) {
            SectionCard(icon: "waveform", title: "Haptics", tint: Theme.faceAccent) {
                MinimalToggle(
                    title: "Enable controller haptics",
                    subtitle: "Gentle taps on clicks, typing, and mode toggles. Requires a compatible controller (Switch Pro, DualSense, Xbox).",
                    isOn: $store.config.hapticsEnabled
                )
            }
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: Theme.s12) {
            shortcut("⌘⌥⌃P", "Toggle")
            Text("or map any button → Toggle")
                .font(Theme.label(10))
                .foregroundStyle(.tertiary)
            Spacer()
            MicroButton(label: "Quit", destructive: true) { NSApp.terminate(nil) }
        }
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack(spacing: Theme.s4) {
            Text(keys)
                .font(Theme.mono(10, .semibold))
                .padding(.horizontal, Theme.s6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .fill(Theme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 0.5)
                )
                .foregroundStyle(.secondary)
            Text(label)
                .font(Theme.label(10))
                .foregroundStyle(.tertiary)
        }
    }

    private func inlineHint(_ k: String, _ a: String) -> some View {
        HStack(spacing: Theme.s4) {
            Text(k)
                .font(Theme.display(9.5, .heavy))
                .tracking(0.5)
                .padding(.horizontal, Theme.s6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous).fill(Theme.surface2)
                )
                .foregroundStyle(.primary.opacity(0.8))
            Text(a).font(Theme.label(10)).foregroundStyle(.secondary)
        }
    }

    // MARK: helpers

    private func binding(for key: String) -> Binding<ButtonAction> {
        Binding<ButtonAction>(
            get: { store.config.buttons[key] ?? .none },
            set: { store.config.buttons[key] = $0 }
        )
    }

    private func faceBinding(_ key: String) -> Binding<String> {
        Binding<String>(
            get: { store.config.faceSwap[key] ?? key },
            set: { store.config.faceSwap[key] = $0 }
        )
    }

    private func customBinding(for key: String) -> Binding<CustomKey?> {
        Binding<CustomKey?>(
            get: { store.config.customKeys[key] },
            set: { store.config.customKeys[key] = $0 }
        )
    }

    static let order = ["A","B","X","Y","UP","DOWN","LEFT","RIGHT","L1","R1","L2","R2","L3","R3","OPT","MENU","HOME","SHARE","TOUCHPAD"]
    static let display: [String: String] = [
        "A": "A", "B": "B", "X": "X", "Y": "Y",
        "UP": "D-Pad ↑", "DOWN": "D-Pad ↓", "LEFT": "D-Pad ←", "RIGHT": "D-Pad →",
        "L1": "L1", "R1": "R1",
        "L2": "L2 / ZL", "R2": "R2 / ZR",
        "L3": "L3 / L Stick", "R3": "R3 / R Stick",
        "OPT": "Options −", "MENU": "Menu +",
        "HOME": "Home", "SHARE": "Capture / Share",
        "TOUCHPAD": "Touchpad Click",
    ]
}

// MARK: - chrome

struct AppMark: View {
    var body: some View {
        ZStack {
            // Monochrome tile — subtle dark glass square with a single white glyph.
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.32)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
    }
}

struct StatusDot: View {
    let active: Bool
    let connected: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: color.opacity(0.7), radius: 4)
    }

    private var color: Color {
        if !connected { return Color(red: 0.68, green: 0.68, blue: 0.72) }
        return active ? Color(red: 0.32, green: 0.85, blue: 0.52)
                      : Color(red: 1.00, green: 0.72, blue: 0.18)
    }
}

struct NavPill: View {
    let tab: Tab
    let selected: Bool
    let ns: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.s6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.title)
                    .font(Theme.label(12, selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.horizontal, Theme.s10)
            .padding(.vertical, Theme.s6)
            .background(
                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: Theme.r8, style: .continuous)
                            .fill(Theme.surface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.r8, style: .continuous)
                                    .strokeBorder(Theme.strokeStrong, lineWidth: 0.5)
                            )
                            .matchedGeometryEffect(id: "nav-bg", in: ns)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct SectionCard<Content: View>: View {
    let icon: String
    let title: String
    let tint: Color
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            HStack(spacing: Theme.s8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Image(systemName: icon)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(Theme.display(12.5, .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if let trailing { trailing }
            }
            content()
        }
        .padding(Theme.s12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.r14, style: .continuous)
                    .fill(Theme.surface1)
                RoundedRectangle(cornerRadius: Theme.r14, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            }
        )
    }
}

struct MicroButton: View {
    let label: String
    var destructive: Bool = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.label(11, .medium))
                .foregroundStyle(destructive ? Color.red.opacity(0.9) : Color.secondary)
                .padding(.horizontal, Theme.s8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .fill(hovered ? Theme.surface2 : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(Theme.easeOut, value: hovered)
    }
}

// MARK: - components

struct MinimalSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let fmt: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s8) {
            HStack {
                Text(title).font(Theme.label(12))
                Spacer()
                Text(String(format: fmt, value))
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Theme.easeOut, value: value)
                    .padding(.horizontal, Theme.s6).padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Theme.surface2)
                    )
            }
            GlassSlider(value: $value, range: range)
        }
    }
}

// Custom slider — translucent track + filled progress + glass thumb.
// Drags respond to any touch along the track (not just the thumb) for a
// more iOS-like feel. No AppKit chrome, so it sits cleanly on glass.
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var trackHeight: CGFloat = 6
    var thumbSize: CGFloat = 16

    @GestureState private var dragging: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let t = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let clamped = min(max(t, 0), 1)
            let thumbX = clamped * w

            ZStack(alignment: .leading) {
                // Base track
                Capsule()
                    .fill(Theme.surface3)
                    .frame(height: trackHeight)
                // Filled progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.92), Color.white.opacity(0.72)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: thumbX, height: trackHeight)
                // Thumb
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.82)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Circle()
                        .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                }
                .frame(width: thumbSize, height: thumbSize)
                .scaleEffect(dragging ? 1.12 : 1.0)
                .shadow(color: .black.opacity(0.25), radius: dragging ? 6 : 3, y: 1)
                .offset(x: thumbX - thumbSize / 2)
                .animation(Theme.springFast, value: dragging)
            }
            .frame(height: max(trackHeight, thumbSize))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragging) { _, s, _ in s = true }
                    .onChanged { g in
                        let pct = min(max(g.location.x / w, 0), 1)
                        let v = range.lowerBound + Double(pct) * (range.upperBound - range.lowerBound)
                        if v != value { value = v }
                    }
            )
        }
        .frame(height: max(trackHeight, thumbSize))
    }
}

struct MinimalToggle: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.label(12))
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.label(10.5))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.springFast) { isOn.toggle() } }
    }
}

// Buttons tab is heavy — 18 rows, each with an AppKit Picker (NSPopUpButton).
// Mounting all 18 synchronously on tab switch is the source of the lag.
// Strategy: show a skeleton briefly while the tab transition finishes, then
// reveal the real rows inside a LazyVStack so offscreen pickers don't mount.
struct MappingPage: View {
    @ObservedObject var store: Store
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s16) {
            SectionCard(
                icon: "square.grid.3x3.fill",
                title: "Button Actions",
                tint: Theme.systemAccent,
                trailing: AnyView(
                    MicroButton(label: "Reset") {
                        store.config.buttons = Config.defaultMap
                    }
                )
            ) {
                if loaded {
                    LazyVStack(spacing: Theme.s2) {
                        ForEach(ConfigView.order, id: \.self) { key in
                            MappingRow(
                                key: key,
                                displayName: ConfigView.display[key] ?? key,
                                pressed: store.pressedButtons.contains(key),
                                binding: binding(for: key),
                                custom: customBinding(for: key)
                            )
                            if key != ConfigView.order.last { GlassDivider() }
                        }
                    }
                    .transition(.opacity)
                } else {
                    MappingSkeleton()
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Let the tab cross-fade complete before we pay the Picker mount cost.
            // ~90ms is long enough for the animation to settle, short enough not
            // to feel like a page load.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.easeOut(duration: 0.18)) { loaded = true }
            }
        }
    }

    private func binding(for key: String) -> Binding<ButtonAction> {
        Binding<ButtonAction>(
            get: { store.config.buttons[key] ?? .none },
            set: { store.config.buttons[key] = $0 }
        )
    }

    private func customBinding(for key: String) -> Binding<CustomKey?> {
        Binding<CustomKey?>(
            get: { store.config.customKeys[key] },
            set: { store.config.customKeys[key] = $0 }
        )
    }
}

// Skeleton placeholder — same rhythm as real rows so reveal doesn't jump.
// Static (no animation) because the skeleton only lives ~90ms; any shimmer
// would barely start before the real rows replace it.
struct MappingSkeleton: View {
    var body: some View {
        VStack(spacing: Theme.s2) {
            ForEach(0..<8, id: \.self) { i in
                HStack(spacing: Theme.s10) {
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .fill(Theme.surface2)
                        .frame(width: 30, height: 22)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.surface2)
                        .frame(width: 72, height: 10)
                    Spacer()
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .fill(Theme.surface1)
                        .frame(width: 140, height: 22)
                }
                .padding(.vertical, Theme.s6)
                .opacity(0.6)
                if i < 7 { GlassDivider() }
            }
        }
    }
}

struct MappingRow: View {
    let key: String
    let displayName: String
    let pressed: Bool
    @Binding var binding: ButtonAction
    @Binding var custom: CustomKey?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            HStack(spacing: Theme.s10) {
                MinimalBadge(name: key, pressed: pressed)
                Text(displayName)
                    .font(Theme.label(12, .medium))
                    .frame(width: 82, alignment: .leading)
                Spacer()
                Picker("", selection: $binding) {
                    ForEach(ButtonAction.allCases) { a in
                        if a == .custom {
                            Text(custom?.display ?? "Custom Key…").tag(a)
                        } else {
                            Text(a.label).tag(a)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 180)
            }
            if binding == .custom {
                HStack(spacing: Theme.s8) {
                    Spacer().frame(width: 30 + 10 + 82)
                    KeyRecorder(custom: $custom)
                    Spacer()
                }
            }
        }
        .padding(.vertical, Theme.s4)
    }
}

struct KeyRecorder: View {
    @Binding var custom: CustomKey?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: Theme.s6) {
            Text(recording ? "Press any key…" : (custom?.display ?? "—"))
                .font(Theme.mono(11))
                .foregroundStyle(recording ? Color.accentColor
                                 : (custom == nil ? Color.secondary : Color.primary))
                .padding(.horizontal, Theme.s8).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                        .strokeBorder(recording ? Color.accentColor.opacity(0.6)
                                      : Theme.stroke, lineWidth: 0.7)
                )
            MicroButton(label: recording ? "Cancel" : "Record") {
                if recording { stop() } else { start() }
            }
            if custom != nil && !recording {
                Button { custom = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ev in
            let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
            let mods = ev.modifierFlags.intersection(relevant).rawValue
            custom = CustomKey(keyCode: ev.keyCode, modifiers: UInt(mods))
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

struct QuickMap: View {
    let key: String
    @Binding var target: String
    let pressed: Bool

    static let faceKeys = ["A", "B", "X", "Y"]

    var body: some View {
        HStack(spacing: Theme.s8) {
            MinimalBadge(name: key, pressed: pressed)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            Picker("", selection: $target) {
                ForEach(Self.faceKeys, id: \.self) { k in
                    Text(k).tag(k)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.s8)
        .padding(.vertical, Theme.s6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.r8, style: .continuous).fill(Theme.surface2)
                RoundedRectangle(cornerRadius: Theme.r8, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            }
        )
    }
}

struct MinimalBadge: View {
    let name: String
    let pressed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                .fill(
                    pressed
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Theme.surface2)
                )
            RoundedRectangle(cornerRadius: Theme.r6, style: .continuous)
                .strokeBorder(pressed ? Color.white.opacity(0.25) : Theme.stroke, lineWidth: 0.6)
            Text(display)
                .font(Theme.display(10, .semibold))
                .foregroundStyle(pressed ? Color.white : Color.primary.opacity(0.8))
        }
        .frame(width: 30, height: 22)
        .scaleEffect(pressed ? 1.08 : 1.0)
        .shadow(color: pressed ? Color.accentColor.opacity(0.55) : Color.clear, radius: 6)
        .animation(Theme.springFast, value: pressed)
    }

    private var display: String {
        switch name {
        case "UP": return "↑"
        case "DOWN": return "↓"
        case "LEFT": return "←"
        case "RIGHT": return "→"
        case "OPT": return "−"
        case "MENU": return "+"
        default: return name
        }
    }
}

import SwiftUI
import AppKit

// Design tokens — single source of truth for spacing, radii, typography,
// motion, and material surfaces. Every view should compose from these
// instead of hand-rolling one-off numbers. Keep the set small; resist the
// urge to add a new token until at least three callers need it.
enum Theme {
    // 4/8/12/16/20/24 spacing scale — everything snaps to 4pt.
    static let s2: CGFloat = 2
    static let s4: CGFloat = 4
    static let s6: CGFloat = 6
    static let s8: CGFloat = 8
    static let s10: CGFloat = 10
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32

    // Corner radii
    static let r6: CGFloat = 6
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12
    static let r14: CGFloat = 14
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let rPill: CGFloat = 999

    // Color tokens — translucent so they read against the underlying vibrancy.
    static let surface1 = Color.white.opacity(0.04)
    static let surface2 = Color.white.opacity(0.07)
    static let surface3 = Color.white.opacity(0.11)
    static let stroke = Color.white.opacity(0.08)
    static let strokeStrong = Color.white.opacity(0.14)
    static let strokeSubtle = Color.white.opacity(0.04)
    static let divider = Color.white.opacity(0.06)
    static let hudBg = Color.black.opacity(0.62)

    // Semantic accent per button kind
    static let faceAccent = Color(red: 1.00, green: 0.35, blue: 0.44)
    static let dpadAccent = Color(red: 0.72, green: 0.50, blue: 1.00)
    static let shoulderAccent = Color(red: 0.42, green: 0.80, blue: 1.00)
    static let systemAccent = Color(red: 0.53, green: 0.66, blue: 1.00)

    // Typography — SF Pro Rounded for display, SF Mono for numbers.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func label(_ size: CGFloat = 12, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat = 11, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Motion presets
    static let springFast = Animation.spring(response: 0.22, dampingFraction: 0.74)
    static let springDefault = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let springSoft = Animation.spring(response: 0.48, dampingFraction: 0.86)
    static let easeOut = Animation.easeOut(duration: 0.18)
}

// Translucent backdrop. Use `.hudWindow` inside floating panels, `.sidebar`
// inside the config popover — the AppKit materials carry macOS vibrancy
// (wallpaper-aware tint + noise + specular).
struct GlassMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = emphasized
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.isEmphasized = emphasized
    }
}

// Card chassis — frosted surface + hairline stroke + very soft shadow.
struct GlassCard: ViewModifier {
    var radius: CGFloat = Theme.r14
    var strong: Bool = false
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? Theme.s12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(strong ? Theme.surface2 : Theme.surface1)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 0.5)
                }
            )
    }
}

// Elevated floating pill — used for HUD chips. Vibrant tint + soft glow
// matched to the caller's accent color.
struct ElevatedPill: ViewModifier {
    var tint: Color
    var radius: CGFloat = Theme.rPill
    var intensity: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Theme.hudBg)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.22 * intensity), tint.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.6
                        )
                }
            )
            .shadow(color: tint.opacity(0.35 * intensity), radius: 14, y: 4)
            .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
    }
}

extension View {
    func glassCard(radius: CGFloat = Theme.r14, strong: Bool = false, padding: CGFloat? = nil) -> some View {
        modifier(GlassCard(radius: radius, strong: strong, padding: padding))
    }
    func elevatedPill(tint: Color = .white, intensity: CGFloat = 1.0, radius: CGFloat = Theme.rPill) -> some View {
        modifier(ElevatedPill(tint: tint, radius: radius, intensity: intensity))
    }
}

// Hairline divider tuned for glass surfaces.
struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 0.5)
    }
}

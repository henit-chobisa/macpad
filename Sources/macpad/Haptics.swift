import Foundation
import GameController
import CoreHaptics

// Thin wrapper over the GCController haptics engine. Posts short
// ambient patterns — "tap" for key / click events, "pulse" for mode
// toggles. All calls are no-ops if the controller doesn't support
// haptics or the user has disabled them in config.
final class Haptics {
    private var engine: CHHapticEngine?
    private(set) var attached: Bool = false
    var enabled: Bool = true

    func attach(_ controller: GCController) {
        guard let haptics = controller.haptics,
              let eng = haptics.createEngine(withLocality: .default) else { return }
        engine = eng
        eng.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }
        eng.stoppedHandler = { _ in }
        do {
            try eng.start()
            attached = true
        } catch {
            print("[haptics] start failed: \(error)")
            attached = false
        }
    }

    func detach() {
        engine?.stop()
        engine = nil
        attached = false
    }

    // Punchier defaults. Layer a sharp transient on top of a brief continuous
    // body so the controller rumble feels like a mechanical click instead of
    // a flat buzz — more intensity + high sharpness = snappier, more alive.
    func tap(intensity: Float = 0.85, sharpness: Float = 1.0) {
        guard enabled else { return }
        play(events: [
            .init(eventType: .hapticTransient,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: intensity),
                      .init(parameterID: .hapticSharpness, value: sharpness),
                  ], relativeTime: 0),
            .init(eventType: .hapticContinuous,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: intensity * 0.55),
                      .init(parameterID: .hapticSharpness, value: 0.35),
                  ], relativeTime: 0, duration: 0.04),
        ])
    }

    func pulseUp() {
        guard enabled else { return }
        play(events: [
            .init(eventType: .hapticTransient,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 0.7),
                      .init(parameterID: .hapticSharpness, value: 0.5),
                  ], relativeTime: 0),
            .init(eventType: .hapticContinuous,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 0.45),
                      .init(parameterID: .hapticSharpness, value: 0.35),
                  ], relativeTime: 0.02, duration: 0.09),
            .init(eventType: .hapticTransient,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 1.0),
                      .init(parameterID: .hapticSharpness, value: 1.0),
                  ], relativeTime: 0.12),
        ])
    }

    func pulseDown() {
        guard enabled else { return }
        play(events: [
            .init(eventType: .hapticTransient,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 1.0),
                      .init(parameterID: .hapticSharpness, value: 0.95),
                  ], relativeTime: 0),
            .init(eventType: .hapticContinuous,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 0.5),
                      .init(parameterID: .hapticSharpness, value: 0.3),
                  ], relativeTime: 0.02, duration: 0.11),
            .init(eventType: .hapticTransient,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: 0.55),
                      .init(parameterID: .hapticSharpness, value: 0.2),
                  ], relativeTime: 0.14),
        ])
    }

    func hum(duration: TimeInterval = 0.25, intensity: Float = 0.2) {
        guard enabled else { return }
        play(events: [
            .init(eventType: .hapticContinuous,
                  parameters: [
                      .init(parameterID: .hapticIntensity, value: intensity),
                      .init(parameterID: .hapticSharpness, value: 0.2),
                  ],
                  relativeTime: 0,
                  duration: duration),
        ])
    }

    private func play(events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Engine likely stopped; try to restart so next call works.
            try? engine.start()
        }
    }
}

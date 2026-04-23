<div align="center">

# macpad

### Your game controller is now a mouse.

A native macOS menubar agent that turns a **DualShock 4**, **DualSense**, **Xbox**, or **Switch Pro** controller into a first-class input device — cursor, scroll, keyboard, and every system shortcut you can dream of.

[![Swift 5.9](https://img.shields.io/badge/Swift-5.9+-orange.svg?logo=swift)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg?logo=apple)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

</div>

---

## Why

Your trackpad died. Your mouse is in the other room. The battery on the wireless one is flat. But there's a PS4 pad sitting right next to the couch.

That's the moment macpad was built for. And once you start using a thumbstick for cursor work, a shoulder button for space switching, and an on-screen keyboard to type a password without getting up — you stop wanting the trackpad back.

## What it does

- **Stick-driven cursor** with deadzone, response curve, inertia, and on-demand precision / boost.
- **Right-stick scroll** in both axes, invertible.
- **Every button remappable** — clicks, arrows, text, `⌘Tab`, space switch, Mission Control, Spotlight, Launchpad, media keys, brightness, custom combos.
- **Hold-modifier actions** — map any button to Hold `⌃` / `⇧` / `⌥` / `⌘`. Works exactly like a real modifier: press + another button = combo.
- **On-screen keyboard** driven entirely by the controller, with haptic feedback on every keystroke.
- **PS / Home button works** — even though Apple's driver hides it from the GameController framework (macpad reads the raw HID report instead, same trick Chromium uses for WebHID).
- **Liquid Glass UI** on macOS 26 Tahoe, tasteful matte fallback on older macOS.
- **Punchy CoreHaptics feedback** on every toggle, mode change, and keypress.
- **HUD overlay** shows the last button pressed + the action that fired, so a custom mapping is never a guess.
- **Menubar-only**. No Dock icon, no window management, no friction.

## Supported controllers

| Controller | Sticks / D-pad / Face / Shoulders | Home / PS | Share / Create | Touchpad click |
|---|:---:|:---:|:---:|:---:|
| DualShock 4 <sub>(`054C:09CC`, `054C:05C4`)</sub> | ✅ | ✅ raw HID | ✅ raw HID | ✅ raw HID |
| DualSense <sub>(`054C:0CE6`)</sub>              | ✅ | ✅ raw HID | ✅ raw HID | ✅ raw HID |
| Xbox / Switch Pro / MFi                          | ✅ | driver-dependent | — | — |

Any controller exposing the standard HID GamePad / Joystick usage will work for sticks and face buttons; PS / Share / Touchpad require the raw-report path we've written for Sony controllers.

## Quickstart

```bash
git clone https://github.com/henit-chobisa/macpad.git
cd macpad
swift run
```

On first launch:

1. **Accessibility** prompt — required to synthesize mouse and keyboard events. Grant in *System Settings ▸ Privacy & Security ▸ Accessibility*, relaunch.
2. **Input Monitoring** prompt — required for the raw HID path that unlocks PS / Create / Touchpad. Grant in *System Settings ▸ Privacy & Security ▸ Input Monitoring*, relaunch.
3. Pair the controller over Bluetooth (on DualShock 4: hold `Share + PS` until the light bar flashes rapidly). macpad auto-detects on connect.

> 💡 **Terminal gotcha.** If you run macpad from Terminal, shortcuts you map to `⌃←` / `⌃→` / etc. will be eaten by Terminal itself because *it* is the focused app. For daily use, launch macpad through an `.app` bundle or `open -a` so a different app is foreground.

## Default bindings

| Button              | Action                              |
|---------------------|-------------------------------------|
| Left stick          | Move cursor                         |
| Right stick         | Scroll (x / y)                      |
| A                   | Left click                          |
| B                   | Right click                         |
| X                   | Space                               |
| Y                   | `⌘Return`                           |
| D-pad ↑ / ↓         | Scroll up / down                    |
| D-pad ← / →         | Arrow ← / →                         |
| L1                  | `⌃⇧Tab` (previous tab)              |
| R1                  | `⌃Tab` (next tab)                   |
| L2 (hold)           | Boost sensitivity                   |
| R2 (hold)           | Precision sensitivity               |
| L3 / R3             | Left / right click                  |
| Options `−`         | Escape                              |
| Menu `+`            | `⌘Tab`                              |
| **Home / PS**       | **Toggle macpad on / off**          |
| **Share / Create**  | **Toggle on-screen keyboard**       |
| **Touchpad click**  | Toggle macpad on / off              |
| **L1 + R1 chord**   | Toggle on-screen keyboard           |

All mappings are editable in the config panel (click the menubar icon ▸ *Settings*).

### Global keyboard shortcuts

Useful when the controller isn't within reach:

| Shortcut   | Action                       |
|------------|------------------------------|
| `⌃⌥⌘P`     | Toggle macpad on / off       |
| `⌃⌥⌘K`     | Toggle on-screen keyboard    |

### On-screen keyboard

| Input                          | Effect                               |
|--------------------------------|--------------------------------------|
| D-pad                          | Move selection                       |
| L1 / R1                        | Jump ±5 columns                      |
| A                              | Type selected key                    |
| B                              | Backspace                            |
| X                              | Space                                |
| Y                              | Return                               |
| L2 (hold)                      | Shift (uppercase)                    |
| Menu                           | Close keyboard                       |
| **R2 (hold) + left stick**     | **Drag the keyboard panel**          |

Trackpad / mouse drag also moves the panel (the hosting view overrides `mouseDownCanMoveWindow`).

## Development

### Repository layout

```
macpad/
├── Package.swift              # SwiftPM manifest, single executable target
├── README.md
├── LICENSE
└── Sources/macpad/
    ├── main.swift             # NSApplication bootstrap, global hotkey monitors
    ├── Pad.swift              # Central input dispatcher — sticks → cursor, buttons → actions
    ├── HID.swift              # Raw IOHIDManager listener for DualSense / DualShock 4
    ├── Keyboard.swift         # On-screen keyboard: KeyboardManager + NSPanel host
    ├── Haptics.swift          # CoreHaptics patterns over GameController's haptics engine
    ├── HUD.swift              # Floating overlay for last-pressed-button feedback
    ├── Menubar.swift          # NSStatusItem agent (pause / resume / settings)
    ├── Config.swift           # @Published config struct, button map, ButtonAction enum
    ├── ConfigView.swift       # Full SwiftUI settings UI
    └── Theme.swift            # Shared colors, fonts, spacing tokens
```

### Build & run

```bash
# Debug build + run
swift run

# Release build (optimized)
swift build -c release
.build/release/macpad
```

Swift Package Manager resolves everything, no Xcode project needed. If you want one: `swift package generate-xcodeproj` (deprecated) or just `open Package.swift` — Xcode reads the manifest directly.

### Architecture

**Input path.** Controllers surface through two channels, in parallel:

1. **Apple's `GameController` framework** — standard gamepads (sticks, D-pad, face buttons, shoulders). Bound in `Pad.bind(_:)`.
2. **Raw HID reports** via `IOHIDManager` — the only way to reach PS / Create / Touchpad on Sony controllers, because Apple's driver silently drops those. `HID.swift` registers `IOHIDDeviceRegisterInputReportCallback` per device and decodes the button bits from the raw 64-byte input report. Supports both USB (report `0x01`) and Bluetooth (report `0x11` for DualShock 4, `0x31` for DualSense) layouts; exact byte / bit offsets are commented inline with references to the protocol spec.

Both paths funnel into `Pad.onBtn(_:_:)`. A 50 ms dedup window collapses any doubled events where both sources fire.

**Shoulder chord.** `L1 + R1` toggles the on-screen keyboard. Implementation defers individual L1 / R1 actions by 150 ms; if the opposite shoulder arrives in that window, the chord fires and both press + release are swallowed. A quick tap (< 150 ms press → release) fires the press + release back-to-back as soon as release arrives, so the user never feels the deferral.

**Event synthesis.** `CGEvent` events go to `.cghidEventTap`. Mouse events explicitly set `flags = []` + `mouseEventClickState = 1` — this was a subtle bug fix. Without the flag reset, our modifier-carrying keyboard events (`⌃Tab`, etc.) bled ctrl into the combined session source, and the next left click arrived at apps as `ctrl+click` = right-click on macOS.

**Haptics.** `Haptics` wraps `GCController.haptics`. The `tap()` helper layers a sharp transient + a brief continuous tail (0.04 s) — that one-two structure is what makes a synthesized haptic feel like a real mechanical click rather than a flat buzz. `pulseUp()` / `pulseDown()` chain three events (transient → continuous ramp → transient) for distinct on / off signatures.

**Keyboard panel.** `NSPanel` with `.nonactivatingPanel + .borderless`, no window shadow (so the SwiftUI rounded-rect shadow doesn't fight a native square one behind it). The content view is a `DragHostingView<Content: View>` — a tiny `NSHostingView` subclass that overrides `mouseDownCanMoveWindow` to return `true`, which lets `isMovableByWindowBackground` actually trigger through the SwiftUI hierarchy.

**Liquid Glass.** Keyboard and HUD check `#available(macOS 26.0, *)` and fall back to a matte gradient when not available. `glassEffect(.regular.tint:in:)` is applied inside a `GlassEffectContainer` so the selected-keycap morph can ripple into the panel shape.

### Debugging

Useful toggles:

- `HIDListener.logAllButtons = true` — dumps every HID element event (page / usage / value) — indispensable when a controller's PS button doesn't work because of a non-standard usage code.

If a button isn't reaching macpad:

1. Check the GameController side — `Pad.bind(_:)` logs the full `controller buttons:` list once on connect. If your button name isn't in that list, Apple's driver never exposed it.
2. Check the HID side — `Pad.swift` has a `print` inside `handle()` (guarded by `logAllButtons`). Toggle it on, press the button, see which HID page+usage it fires on.
3. If neither fires, macOS is intercepting it (PS-button-opens-Game-Center is the classic case). Turn off the matching shortcut in *System Settings ▸ Game Controllers*.

### Contributing

PRs are welcome. Rough shape of a good contribution:

1. Open an issue first for anything non-trivial — mapping changes, new actions, UI rewrites. We can iterate on design before you write the code.
2. Match the existing style: SwiftUI for any new UI, no external dependencies if it's avoidable, comments only where the *why* is non-obvious.
3. Test with at least one Sony and one non-Sony controller where possible.
4. Keep commit messages focused — one change per commit, imperative mood ("add battery indicator" not "added battery indicator").

Specific good first issues:

- **`.app` bundle** packaging + codesign + notarize pipeline.
- **Launch at Login** toggle using `SMAppService`.
- **Menubar battery indicator** — DualSense report `0x01`, byte 52 has the battery %; DualShock 4 report `0x01`, byte 30 low nibble has it.
- **Live stick visualizer** in the config UI — plot the deadzone and response curve with the live stick position overlay.

## Known limitations

- **Synthetic CGEvents are not always accepted by macOS Symbolic Hotkey dispatch.** For most hotkeys (`⌃←` space switch, `⌃↑` Mission Control, `⌘Space` Spotlight) we post the event and it triggers. For some, macOS filters them out. Workaround: move focus off the terminal (terminals intercept `⌃←` / `⌃→` as escape sequences before the OS sees them).
- **PS button requires Input Monitoring.** Without it, we can't read the raw HID report; the GameController framework won't surface the button either; there is no workaround.
- **Packaged `.app` bundle is not in-tree yet.** For now build + run via `swift run` or ship a custom bundle yourself — see roadmap.

## Roadmap

- [ ] `.app` bundle with proper `Info.plist` + signing
- [ ] Launch at Login
- [ ] Menubar battery indicator (DualShock 4 / DualSense)
- [ ] Per-app mapping profiles (auto-switch on front-app change)
- [ ] Live visualizer for stick deadzone + response curve
- [ ] Scroll momentum / friction
- [ ] Auto-pause when the laptop trackpad is in use

## Credits & references

- [nondebug/dualsense](https://github.com/nondebug/dualsense) — DualSense HID report spec.
- [psdevwiki — DS4-USB](https://www.psdevwiki.com/ps4/DS4-USB) — DualShock 4 report layouts.
- [Chrome WebHID](https://developer.chrome.com/docs/capabilities/hid) — the approach of reading raw HID reports when the OS gamepad API hides buttons.
- Apple [GameController](https://developer.apple.com/documentation/gamecontroller), [CoreHaptics](https://developer.apple.com/documentation/corehaptics), and [IOKit HID](https://developer.apple.com/documentation/iokit) frameworks.

## License

[MIT](./LICENSE) © 2026 Henit Chobisa.

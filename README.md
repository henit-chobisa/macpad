# macpad

Turn your game controller into a first-class macOS input device. Mouse, scroll, keyboard, system shortcuts — all from a DualShock 4, DualSense, Xbox, or Switch Pro controller.

Built for the moment your trackpad gives up and you still have a PS4 pad lying next to the couch.

## Highlights

- **Precise cursor control** — left stick drives the pointer with a tunable deadzone, response curve, inertia, and on-demand precision / boost holds.
- **Right-stick scroll** — two-axis pixel scroll with configurable speed and inversion per axis.
- **Every button remappable** — left / right / middle click, arrow keys, text keys, `⌘Tab`, `⌃Tab`, copy / paste, Mission Control, space switch, Spotlight, Launchpad, media keys, brightness, volume, custom key combos… full list in the config panel.
- **Hold modifiers** — map any button to Hold ⌃ / ⇧ / ⌥ / ⌘. Works exactly like a physical modifier: press + any other button = that modifier combo.
- **On-screen keyboard** — 40-key grid driven entirely by the controller. Navigate with D-pad / sticks, type with A, backspace with B, space with X, return with Y, shift-hold with L2. Toggle anywhere with `L1+R1`.
- **Drag the keyboard** — physical trackpad drag works, and R2 + left stick drags it without leaving the gamepad.
- **PS / Home button capture** — Apple's DualShock / DualSense driver hides the PS button from the GameController framework. macpad reads the raw HID input report directly (same approach Chromium uses for WebHID) and parses the button bit itself.
- **Liquid Glass UI** — keyboard and HUD use Tahoe's `glassEffect` when available, with a darker matte fallback for older macOS.
- **Haptics** — punchy mechanical-click-feel transients on every toggle, mode change, and keyboard keystroke. Enable / disable in config.
- **HUD** — floating heads-up display shows the last button pressed and its resolved action, so custom mappings never feel opaque.
- **Menubar agent** — no Dock icon, no window. Lives in the menubar with a pause / resume toggle and a single click into the full config.

## Supported controllers

| Controller | Cursor / sticks / D-pad / face / shoulders | Home / PS | Share / Create | Touchpad click |
|---|---|---|---|---|
| DualShock 4 (`0x054C:0x09CC`, `0x054C:0x05C4`) | ✅ via GameController | ✅ via raw HID | ✅ via raw HID | ✅ via raw HID |
| DualSense (`0x054C:0x0CE6`) | ✅ via GameController | ✅ via raw HID | ✅ via raw HID | ✅ via raw HID |
| Xbox / Switch Pro / MFi | ✅ via GameController | depends on driver | — | — |

Other controllers that speak the standard HID GamePad or Joystick usage work for sticks and face buttons but may not expose Home / Share.

## Requirements

- macOS 14 or newer (Liquid Glass rendering kicks in on macOS 26 Tahoe).
- Swift 5.9+ toolchain (ships with Xcode 15).
- A supported controller, paired over Bluetooth or USB.

## Install & run

```bash
git clone https://github.com/henit-chobisa/macpad.git
cd macpad
swift build
.build/debug/macpad
```

First launch:

1. macOS will prompt for **Accessibility** permission — required to post synthetic mouse and key events. Grant it in System Settings ▸ Privacy & Security ▸ Accessibility, then relaunch.
2. macOS will prompt for **Input Monitoring** — required for the raw HID path that catches the PS / Create / Touchpad buttons. Grant it in System Settings ▸ Privacy & Security ▸ Input Monitoring, then relaunch.

Pair the controller via System Settings ▸ Bluetooth (DualShock 4: hold `Share + PS` until the light bar flashes). macpad auto-detects on connect.

> **Tip:** running from Terminal works, but Terminal will swallow any shortcut you map to `⌃←` / `⌃→` / similar because the focused app is Terminal itself. For day-to-day use, launch macpad out of an app bundle or via `open -a` so another app has the focus.

## Default bindings

| Button | Action |
|---|---|
| Left stick | Mouse cursor |
| Right stick | Scroll (x / y) |
| A | Left click |
| B | Right click |
| X | Space |
| Y | `⌘Return` |
| D-pad ↑ / ↓ | Scroll up / down |
| D-pad ← / → | Arrow left / right |
| L1 | `⌃⇧Tab` (prev browser tab) |
| R1 | `⌃Tab` (next browser tab) |
| L2 (hold) | Boost sensitivity |
| R2 (hold) | Precision sensitivity |
| L3 / R3 | Left / right click |
| Options (−) | Escape |
| Menu (+) | `⌘Tab` |
| Home / PS | Toggle macpad on/off |
| Share / Create | Toggle on-screen keyboard |
| Touchpad click | Toggle macpad on/off |
| `L1 + R1` (chord) | Toggle on-screen keyboard |

All of these are editable in the config panel.

## Keyboard shortcuts (global)

| Shortcut | Action |
|---|---|
| `⌃⌥⌘P` | Toggle macpad on / off |
| `⌃⌥⌘K` | Toggle on-screen keyboard |

Useful if you temporarily don't have the controller within reach.

## On-screen keyboard

| Controller input | Effect |
|---|---|
| D-pad | Move selection one cell |
| L1 / R1 | Jump 5 columns (quick navigation) |
| A | Type selected key |
| B | Backspace |
| X | Space |
| Y | Return |
| L2 (hold) | Shift (uppercase) |
| Menu | Close keyboard |
| R2 (hold) + left stick | Drag the keyboard panel around the screen |

The panel is also draggable with a physical mouse / trackpad.

## Architecture

```
Pad          — central input dispatcher, cursor math, action performer
HID          — raw IOHIDManager listener, parses DualSense / DualShock 4 input
               reports for PS / Share / Touchpad bits the GC framework hides
Keyboard     — SwiftUI on-screen keyboard + NSPanel host with window-drag override
Haptics      — CoreHaptics patterns layered on GameController's haptics engine
Config       — @Published struct with button map, face-swap, tuning values
ConfigView   — full settings UI (button remapper, sticks, haptics, shortcuts)
Menubar      — NSStatusItem with pause / resume / open-config
HUD          — floating overlay panel showing the last button / action
```

The raw HID path in `HID.swift` is what makes PS / Create work — macOS's standard `GCController.physicalInputProfile` doesn't expose those buttons. macpad opens the device with `IOHIDDeviceRegisterInputReportCallback`, pulls the full input report, and masks the button bit itself. Bytes for each layout (USB vs Bluetooth, DualShock 4 vs DualSense) are documented inline.

## Known constraints

- macOS filters synthetic `CGEvent`s out of Symbolic Hotkey dispatch under some conditions. The current defaults route system-level shortcuts through `keyMod` with an explicit `CGEventFlags`, which works in most foreground apps. If a specific shortcut refuses to fire, move focus off Terminal — terminals interpret `⌃←` / `⌃→` as cursor escape codes and consume them before macOS can see them.
- PS-button capture requires Input Monitoring permission. Without it, the GameController framework won't surface the button and macpad can't see the raw HID report either.
- `.app` bundle packaging and Launch-at-Login are not wired up yet. Track that and a few other items in the TODO below.

## Roadmap

- `.app` bundle with proper Info.plist + codesign pipeline
- Launch at Login toggle
- Menubar battery indicator (DualShock 4 / DualSense report already includes it)
- Per-app mapping profiles (auto-switch on frontmost app)
- Live visualizer for stick deadzone + response curve in config
- Scroll momentum / friction curve
- Auto-pause when the laptop trackpad is in use

## License

MIT.

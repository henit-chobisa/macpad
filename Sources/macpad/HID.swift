import Foundation
import IOKit
import IOKit.hid

// Raw HID listener. Mirrors Chromium's WebHID approach — reads full input
// report buffer and parses button bits directly, bypassing macOS's
// element-level intercept that hides PS/Create on DualSense.
final class HIDListener {
    private var manager: IOHIDManager?
    var onHome: ((Bool) -> Void)?
    var onShare: ((Bool) -> Void)?
    var onTouchpad: ((Bool) -> Void)?
    var logAllButtons: Bool = false  // per-element log (noisy, off by default)

    private static let reportSize = 78  // DualSense BT input reports run up to 78 bytes
    private var buffer = [UInt8](repeating: 0, count: reportSize)
    private var last: (home: Bool, share: Bool, touchpad: Bool) = (false, false, false)
    private var currentPID: Int = 0  // last attached Sony controller PID

    func start() {
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [[String: Any]] = [
            // Sony DualSense + DualShock 4 explicit match.
            [kIOHIDVendorIDKey as String: 0x054C, kIOHIDProductIDKey as String: 0x0CE6],
            [kIOHIDVendorIDKey as String: 0x054C, kIOHIDProductIDKey as String: 0x09CC],
            [kIOHIDVendorIDKey as String: 0x054C, kIOHIDProductIDKey as String: 0x05C4],
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_GamePad],
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Joystick],
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_MultiAxisController],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(m, match as CFArray)

        let ctx = Unmanaged.passUnretained(self).toOpaque()

        // When a matching device appears, open it and hook its raw input reports.
        IOHIDManagerRegisterDeviceMatchingCallback(m, { ctx, _, _, device in
            guard let ctx = ctx else { return }
            let l = Unmanaged<HIDListener>.fromOpaque(ctx).takeUnretainedValue()
            l.attach(device)
        }, ctx)

        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let r = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        if r != kIOReturnSuccess {
            print("[macpad] IOHIDManagerOpen failed: \(String(format: "0x%x", r)) — grant Input Monitoring permission in System Settings ▸ Privacy & Security.")
        }
        manager = m
    }

    private func attach(_ device: IOHIDDevice) {
        let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        if vid == 0x054C { currentPID = pid }

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        buffer.withUnsafeMutableBufferPointer { bp in
            guard let base = bp.baseAddress else { return }
            IOHIDDeviceRegisterInputReportCallback(
                device, base, HIDListener.reportSize,
                { ctx, _, _, _, reportID, report, length in
                    guard let ctx = ctx else { return }
                    let l = Unmanaged<HIDListener>.fromOpaque(ctx).takeUnretainedValue()
                    l.parseReport(reportID: reportID, report: report, length: length)
                }, ctx)
        }
    }

    // Sony controller input report layouts (buffer omits the reportID byte).
    // DualSense (pid 0x0CE6):
    //   USB  reportID 0x01 — PS=buf[9].bit0  Create=buf[8].bit4  Touchpad=buf[9].bit1
    //   BT   reportID 0x31 — PS=buf[10].bit0 Create=buf[9].bit4  Touchpad=buf[10].bit1
    // DualShock 4 (pid 0x09CC / 0x05C4):
    //   USB  reportID 0x01 — PS=buf[6].bit0  Share=buf[5].bit4   Touchpad=buf[6].bit1
    //   BT   reportID 0x11 — PS=buf[9].bit0  Share=buf[8].bit4   Touchpad=buf[9].bit1
    private func parseReport(reportID: UInt32, report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let psIdx: Int, shareIdx: Int, touchIdx: Int
        let isDualSense = (currentPID == 0x0CE6)
        switch (reportID, isDualSense) {
        case (0x01, true) where length > 9:
            psIdx = 9; shareIdx = 8; touchIdx = 9
        case (0x31, true) where length > 10:
            psIdx = 10; shareIdx = 9; touchIdx = 10
        case (0x01, false) where length > 6:
            psIdx = 6; shareIdx = 5; touchIdx = 6
        case (0x11, false) where length > 9:
            psIdx = 9; shareIdx = 8; touchIdx = 9
        default:
            return
        }
        let home = (report[psIdx] & 0x01) != 0
        let share = (report[shareIdx] & 0x10) != 0
        let touch = (report[touchIdx] & 0x02) != 0
        if home != last.home { onHome?(home) }
        if share != last.share { onShare?(share) }
        if touch != last.touchpad { onTouchpad?(touch) }
        last = (home, share, touch)
    }
}

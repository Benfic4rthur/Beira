import AppKit
import ApplicationServices
import BeiraCore

enum SystemControls {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Returns whether event construction/posting was possible, not hardware readback.
    static func adjust(_ control: Control, steps: Int, fine: Bool, limit: ControlLimit? = nil) -> Bool {
        guard accessibilityGranted, steps != 0 || limit != nil else { return false }
        // At an end zone, a full-range key batch saturates from any current level.
        // This happens once per arrival, independently of sensitivity/fine mode.
        let effectiveSteps = limit.map { $0 == .maximum ? (fine ? 64 : 16) : -(fine ? 64 : 16) } ?? steps
        let key: Int = control == .volume ? (effectiveSteps > 0 ? 0 : 1) : (effectiveSteps > 0 ? 2 : 3)
        let modifiers: NSEvent.ModifierFlags = fine ? [.shift, .option] : []
        // Build every event first, so a failed allocation cannot leave a lone key-down.
        var events: [CGEvent] = []
        for _ in 0..<min(64, abs(effectiveSteps)) {
            for down in [true, false] {
                let phase = down ? 0xA : 0xB
                let data = (key << 16) | (phase << 8)
                guard let nsEvent = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                    modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: 0, context: nil, subtype: 8, data1: data, data2: -1),
                    let cgEvent = nsEvent.cgEvent else { return false }
                events.append(cgEvent)
            }
        }
        for event in events { event.post(tap: .cgSessionEventTap) }
        return true
    }
}

final class CursorGuard {
    private var anchor: CGPoint?
    private var timer: Timer?
    private var lastFrame = 0.0

    func begin() {
        guard anchor == nil else { return }
        anchor = CGEvent(source: nil)?.location
        guard anchor != nil else { return }
        lastFrame = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Never hold the pointer indefinitely if the input stream disappears.
            if ProcessInfo.processInfo.systemUptime - self.lastFrame > 0.2 { self.end() }
            else if let anchor = self.anchor { CGWarpMouseCursorPosition(anchor) }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func restore() {
        lastFrame = ProcessInfo.processInfo.systemUptime
        if let anchor { CGWarpMouseCursorPosition(anchor) }
    }
    func end() { timer?.invalidate(); timer = nil; anchor = nil }
}

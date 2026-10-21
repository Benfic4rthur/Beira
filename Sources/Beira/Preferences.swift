import Foundation
import BeiraCore

struct Preferences: Codable, Equatable {
    var enabled = true
    var edgeWidth = 0.025
    var sensitivity = 1.0
    var fineControl = true
    var freezeCursor = true
    var protectTyping = true
    var requireOption = false
    var swapped = false
    var bottomOnly = false
    var hapticFeedback = true

    init() {}
    private enum CodingKeys: String, CodingKey {
        case enabled, edgeWidth, sensitivity, fineControl, freezeCursor, protectTyping
        case requireOption, swapped, bottomOnly, hapticFeedback
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        edgeWidth = try values.decodeIfPresent(Double.self, forKey: .edgeWidth) ?? edgeWidth
        sensitivity = try values.decodeIfPresent(Double.self, forKey: .sensitivity) ?? sensitivity
        fineControl = try values.decodeIfPresent(Bool.self, forKey: .fineControl) ?? fineControl
        freezeCursor = try values.decodeIfPresent(Bool.self, forKey: .freezeCursor) ?? freezeCursor
        protectTyping = try values.decodeIfPresent(Bool.self, forKey: .protectTyping) ?? protectTyping
        requireOption = try values.decodeIfPresent(Bool.self, forKey: .requireOption) ?? requireOption
        swapped = try values.decodeIfPresent(Bool.self, forKey: .swapped) ?? swapped
        bottomOnly = try values.decodeIfPresent(Bool.self, forKey: .bottomOnly) ?? bottomOnly
        hapticFeedback = try values.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? hapticFeedback
    }

    var gestureConfiguration: GestureConfiguration {
        var c = GestureConfiguration()
        c.edgeWidth = edgeWidth
        c.stepDistance = 0.90 / (fineControl ? 64 : 16) / sensitivity
        c.swapped = swapped
        c.bottomOnly = bottomOnly
        return c
    }
    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: "preferences.v1"),
              var p = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        p.edgeWidth = min(0.08, max(0.01, p.edgeWidth.isFinite ? p.edgeWidth : 0.025))
        p.sensitivity = min(2, max(0.5, p.sensitivity.isFinite ? p.sensitivity : 1))
        return p
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "preferences.v1") }
    }
}

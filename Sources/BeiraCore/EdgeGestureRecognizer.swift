import Foundation

public struct Contact: Equatable, Sendable {
    public let id: Int
    public let x: Double
    public let y: Double
    public let state: Int
    public var isActive: Bool { state == 3 || state == 4 }

    public init(id: Int, x: Double, y: Double, state: Int = 4) {
        self.id = id; self.x = x; self.y = y; self.state = state
    }
}

public enum Edge: String, Sendable { case left, right }
public enum Control: String, Sendable { case volume, brightness }
public enum ControlLimit: String, Sendable { case minimum, maximum }

public struct GestureConfiguration: Sendable {
    public var edgeWidth: Double = 0.025
    public var activationDistance: Double = 0.018
    // 90% of the surface spans all 64 fine system-key increments.
    public var stepDistance: Double = 0.90 / 64
    public var swapped: Bool = false
    public var bottomOnly: Bool = false
    public init() {}
}

public struct GestureUpdate: Sendable {
    public var edge: Edge?
    public var isAdjusting = false
    public var started = false
    public var steps = 0
    public var limit: ControlLimit?
    public var control: Control?
    public init() {}
}

/// Independent of AppKit and the private input API; no events are emitted here.
public struct EdgeGestureRecognizer {
    private enum Phase {
        case idle
        case candidate(id: Int, edge: Edge, x: Double, y: Double)
        case adjusting(id: Int, edge: Edge, lastY: Double, remainder: Double, limit: ControlLimit?)
        case untilLift
    }
    private var phase: Phase = .idle
    public init() {}

    /// Pause/settings/permission transitions must not adopt a finger already down.
    public mutating func cancelUntilLift() { phase = .untilLift }
    public mutating func reset() { phase = .idle }

    public mutating func process(_ contacts: [Contact], configuration c: GestureConfiguration,
                                 blocked: Bool = false) -> GestureUpdate {
        let active = contacts.filter(\.isActive)
        guard !active.isEmpty else { phase = .idle; return GestureUpdate() }
        guard !blocked, active.count == 1,
              let touch = active.first,
              touch.x.isFinite, touch.y.isFinite,
              (0...1).contains(touch.x), (0...1).contains(touch.y)
        else { phase = .untilLift; return GestureUpdate() }

        let width = min(0.12, max(0.005, c.edgeWidth))
        let activation = max(0.005, c.activationDistance)
        let stepSize = c.stepDistance.isFinite ? max(0.005, c.stepDistance) : 0.90 / 64
        let edge: Edge? = touch.x <= width ? .left : (touch.x >= 1 - width ? .right : nil)
        var update = GestureUpdate()

        switch phase {
        case .idle:
            guard let edge, !c.bottomOnly || touch.y <= 0.3 else {
                phase = .untilLift; return update
            }
            phase = .candidate(id: touch.id, edge: edge, x: touch.x, y: touch.y)
            update.edge = edge
        case let .candidate(id, origin, startX, startY):
            guard touch.id == id, edge == origin else {
                phase = .untilLift; return update
            }
            let dy = touch.y - startY
            let dx = abs(touch.x - startX)
            // Commit horizontal starts to ordinary pointer use even if the same
            // finger later turns vertically while it is still inside the band.
            if dx >= 0.01 && dx > abs(dy) * 1.2 {
                phase = .untilLift; return update
            }
            guard abs(dy) >= activation else { update.edge = origin; return update }
            guard abs(dy) >= dx * 1.5 else { phase = .untilLift; return update }
            // Once vertical intent is established, include the activation travel.
            // Discarding it made a full stroke miss part of the output range.
            let movement = Self.movement(from: startY, to: touch.y, remainder: 0, previousLimit: nil, stepSize: stepSize)
            phase = .adjusting(id: id, edge: origin, lastY: touch.y, remainder: movement.remainder, limit: movement.reachedLimit)
            update.edge = origin; update.isAdjusting = true; update.started = true
            update.steps = movement.steps; update.limit = movement.emittedLimit
        case let .adjusting(id, origin, previousY, remainder, previousLimit):
            // Slight inward drift is tolerated; leaving the band cancels until lift.
            let inBand = origin == .left ? touch.x <= width + 0.025 : touch.x >= 1 - width - 0.025
            guard touch.id == id, inBand else { phase = .untilLift; return update }
            let movement = Self.movement(from: previousY, to: touch.y, remainder: remainder,
                                         previousLimit: previousLimit, stepSize: stepSize)
            phase = .adjusting(id: id, edge: origin, lastY: touch.y,
                               remainder: movement.remainder, limit: movement.reachedLimit)
            update.edge = origin; update.isAdjusting = true
            update.steps = movement.steps; update.limit = movement.emittedLimit
        case .untilLift: break
        }
        if let edge = update.edge {
            let volumeOnLeft = !c.swapped
            update.control = (edge == .left) == volumeOnLeft ? .volume : .brightness
        }
        return update
    }

    private static func movement(from previousY: Double, to y: Double, remainder: Double,
                                 previousLimit: ControlLimit?, stepSize: Double)
        -> (steps: Int, remainder: Double, reachedLimit: ControlLimit?, emittedLimit: ControlLimit?) {
        // Finger centers rarely reach exactly 0 or 1. End zones make each end of
        // the physical stroke reliably reach the corresponding system limit.
        let zone: ControlLimit? = y <= 0.06 ? .minimum : (y >= 0.94 ? .maximum : nil)
        if let previousLimit, zone == previousLimit { return (0, 0, previousLimit, nil) }
        let delta = y - previousY
        if let zone, (zone == .minimum && delta < 0) || (zone == .maximum && delta > 0) {
            return (0, 0, zone, zone)
        }
        let total = remainder + delta
        // Keep complete rapid-stroke travel. The old four-step/frame cap dropped
        // movement. A batch is bounded to one full system range instead.
        let steps = min(64, max(-64, Int((total / stepSize).rounded(.towardZero))))
        let rest = total - Double(steps) * stepSize
        return (steps, min(stepSize, max(-stepSize, rest)), nil, nil)
    }
}

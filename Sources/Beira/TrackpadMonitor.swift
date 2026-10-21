import Foundation
import BeiraCore
import TrackpadBridge

private final class FrameRelay {
    let receive: ([Contact], Double) -> Void
    init(_ receive: @escaping ([Contact], Double) -> Void) { self.receive = receive }
}

private let frameCallback: BeiraFrameHandler = { context, contacts, count, timestamp in
    guard let context else { return }
    let relay = Unmanaged<FrameRelay>.fromOpaque(context).takeUnretainedValue()
    let snapshot: [Contact]
    if let contacts, count > 0 {
        snapshot = UnsafeBufferPointer(start: contacts, count: Int(count)).map {
            Contact(id: Int($0.identifier), x: $0.x, y: $0.y, state: Int($0.state))
        }
    } else { snapshot = [] }
    // The private buffer is valid only during this callback; snapshot owns its values.
    let receivedAt = ProcessInfo.processInfo.systemUptime
    DispatchQueue.main.async { relay.receive(snapshot, receivedAt) }
}

final class TrackpadMonitor {
    private var relay: FrameRelay?
    private var generation = 0
    var onFrame: (([Contact], Double) -> Void)?
    private(set) var deviceName = "Trackpad"

    func start() -> String? {
        stop()
        let expected = generation
        let relay = FrameRelay { [weak self] contacts, time in
            guard let self, self.generation == expected else { return }
            self.onFrame?(contacts, time)
        }
        self.relay = relay
        if BeiraTrackpadStart(frameCallback, Unmanaged.passUnretained(relay).toOpaque()) == 0 {
            self.relay = nil
            return String(cString: BeiraTrackpadError())
        }
        deviceName = String(cString: BeiraTrackpadDeviceKind())
        return nil
    }

    func stop() {
        generation += 1
        BeiraTrackpadStop()
        relay = nil
    }
}

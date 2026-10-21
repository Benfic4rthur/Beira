import AppKit
import Combine
import BeiraCore
import ServiceManagement

final class AppState: ObservableObject {
    @Published var preferences = Preferences.load() {
        didSet { preferences.save(); cancelGesture(); onStatusChange?() }
    }
    @Published private(set) var permissionGranted = SystemControls.accessibilityGranted
    @Published private(set) var monitoring = false
    @Published private(set) var deviceName = "Procurando trackpad…"
    @Published private(set) var error: String?
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var activeEdge: Edge?
    @Published private(set) var isAdjusting = false
    @Published private(set) var lastAction = "Deslize pelas bordas para experimentar."
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
    var onStatusChange: (() -> Void)?

    private let monitor = TrackpadMonitor()
    private var recognizer = EdgeGestureRecognizer()
    private let cursor = CursorGuard()
    private var globalKeyboard: Any?
    private var localKeyboard: Any?
    private var permissionTimer: Timer?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var lastKeyPress = -Double.infinity
    private var lastPublishedFrame = 0.0
    private var lastReceivedFrame: Double?
    private var lastHapticTime = -Double.infinity
    private var hadActiveContacts = false
    private var sleeping = false
    private var wakeGeneration = 0

    var statusTitle: String {
        if error != nil { return "Trackpad indisponível" }
        if !preferences.enabled { return "Beira pausado" }
        if !permissionGranted { return "Falta uma permissão" }
        return monitoring ? "Pronto para deslizar" : "Conectando…"
    }

    func start() {
        monitor.onFrame = { [weak self] contacts, timestamp in self?.receive(contacts, timestamp: timestamp) }
        localKeyboard = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.recordTyping(); return event
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
        let center = NSWorkspace.shared.notificationCenter
        lifecycleObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.sleeping = true; self.wakeGeneration += 1
                self.cancelGesture(); self.monitor.stop(); self.monitoring = false
            })
        lifecycleObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.sleeping = false; self.wakeGeneration += 1
                let generation = self.wakeGeneration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, !self.sleeping, self.wakeGeneration == generation else { return }
                    self.reconnect()
                }
            })
        refreshPermission()
        reconnect()
    }

    func reconnect() {
        guard !sleeping else { return }
        cancelGesture()
        lastReceivedFrame = nil
        hadActiveContacts = false
        contacts = []
        error = monitor.start()
        monitoring = error == nil
        deviceName = monitoring ? monitor.deviceName : "Nenhum trackpad conectado"
        onStatusChange?()
    }

    func refreshPermission() {
        let granted = SystemControls.accessibilityGranted
        if permissionGranted != granted {
            permissionGranted = granted; cancelGesture(); onStatusChange?()
        }
        if granted, globalKeyboard == nil {
            globalKeyboard = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                self?.recordTyping()
            }
        } else if !granted, let globalKeyboard {
            NSEvent.removeMonitor(globalKeyboard); self.globalKeyboard = nil
        }
    }

    private func recordTyping() {
        lastKeyPress = ProcessInfo.processInfo.systemUptime
        if preferences.protectTyping { cancelGesture() }
    }

    func cancelGesture() {
        recognizer.cancelUntilLift()
        cursor.end()
        activeEdge = nil; isAdjusting = false
    }

    private func receive(_ frame: [Contact], timestamp: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - timestamp < 0.15 else { cancelGesture(); return }
        if hadActiveContacts, let previous = lastReceivedFrame, timestamp - previous > 0.25 { cancelGesture() }
        lastReceivedFrame = timestamp
        let active = frame.filter(\.isActive)
        hadActiveContacts = !active.isEmpty
        let typing = preferences.protectTyping && now - lastKeyPress < 0.65
        let optionMissing = preferences.requireOption && !NSEvent.modifierFlags.contains(.option)
        let blocked = !preferences.enabled || !permissionGranted || typing || optionMissing || sleeping
        let update = recognizer.process(frame, configuration: preferences.gestureConfiguration, blocked: blocked)
        if update.started, preferences.freezeCursor { cursor.begin() }
        if update.isAdjusting { cursor.restore() } else { cursor.end() }
        // UI rendering runs at <=30 Hz; recognition consumes every contact frame.
        if now - lastPublishedFrame >= 1.0 / 30 || active.isEmpty || update.started {
            contacts = active; activeEdge = update.edge; isAdjusting = update.isAdjusting
            lastPublishedFrame = now
        }
        if update.steps != 0 || update.limit != nil, let control = update.control,
           SystemControls.adjust(control, steps: update.steps, fine: preferences.fineControl, limit: update.limit) {
            let name = control == .volume ? "Volume" : "Brilho"
            if let limit = update.limit { lastAction = "\(name) · \(limit == .maximum ? "máximo" : "mínimo")" }
            else { lastAction = "\(name) \(update.steps > 0 ? "↑" : "↓")" }
            // One subtle detent per emitted adjustment batch, capped at 20 Hz.
            // The hardware decides whether haptics can be played at that moment.
            if preferences.hapticFeedback, now - lastHapticTime >= 0.05 {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                lastHapticTime = now
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { loginError = "Não foi possível alterar o início automático: \(error.localizedDescription)" }
    }

    func stop() {
        wakeGeneration += 1; sleeping = true
        cursor.end(); monitor.stop(); monitoring = false
        permissionTimer?.invalidate()
        if let globalKeyboard { NSEvent.removeMonitor(globalKeyboard) }
        if let localKeyboard { NSEvent.removeMonitor(localKeyboard) }
        globalKeyboard = nil; localKeyboard = nil
        for observer in lifecycleObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        lifecycleObservers.removeAll()
    }
}

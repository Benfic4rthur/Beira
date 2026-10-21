import AppKit
import SwiftUI

@main
enum BeiraApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Stable bundle identity is required for an enduring Accessibility grant.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            for right in [false, true] {
                let outer: CGFloat = right ? 14 : 4
                let inner: CGFloat = right ? 11 : 7
                let bracket = NSBezierPath()
                bracket.move(to: NSPoint(x: inner, y: 14))
                bracket.line(to: NSPoint(x: outer, y: 14))
                bracket.line(to: NSPoint(x: outer, y: 4))
                bracket.line(to: NSPoint(x: inner, y: 4))
                bracket.lineWidth = 1.8
                bracket.lineCapStyle = .round
                bracket.lineJoinStyle = .round
                bracket.stroke()
            }
            return true
        }
        menuIcon.isTemplate = true
        menuIcon.accessibilityDescription = "Beira"
        statusItem.button?.image = menuIcon
        statusItem.button?.toolTip = "Beira — brilho e volume nas bordas"
        state.onStatusChange = { [weak self] in
            self?.updateMenu()
            DispatchQueue.main.async { self?.fitSettingsWindow() }
        }
        let appMenu = NSMenu()
        let root = NSMenuItem(); root.submenu = NSMenu()
        root.submenu?.addItem(withTitle: "Ajustes do Beira…", action: #selector(showSettings), keyEquivalent: ",").target = self
        root.submenu?.addItem(.separator())
        root.submenu?.addItem(withTitle: "Encerrar Beira", action: #selector(quit), keyEquivalent: "q").target = self
        appMenu.addItem(root); NSApp.mainMenu = appMenu
        state.start(); updateMenu()
        if !UserDefaults.standard.bool(forKey: "hasOpenedSettings") || !state.permissionGranted {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
        }
    }

    private func updateMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: "Beira · \(state.statusTitle)", action: nil, keyEquivalent: "")
        title.isEnabled = false; menu.addItem(title)
        menu.addItem(.separator())
        let toggle = menu.addItem(withTitle: state.preferences.enabled ? "Pausar Beira" : "Ativar Beira", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(withTitle: "Ajustes…", action: #selector(showSettings), keyEquivalent: ",").target = self
        if !state.permissionGranted {
            menu.addItem(withTitle: "Permitir acesso…", action: #selector(requestPermission), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Encerrar Beira", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.appearsDisabled = !state.preferences.enabled
    }

    @objc private func toggleEnabled() { state.preferences.enabled.toggle() }
    @objc private func requestPermission() { SystemControls.requestAccessibility() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showSettings() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 780),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Beira"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(state: state))
            self.window = window
            fitSettingsWindow()
            window.center()
        }
        fitSettingsWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func fitSettingsWindow() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        window.setContentSize(size)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { state.stop() }
}

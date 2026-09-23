import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = BrowserModel()
    private var window: NSWindow!
    private var settings: NSWindow?
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["keepRunning": true, "privateNotices": true, "noticeSound": true])
        model.openWindow = { [weak self] in self?.showWindow() }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Safefy Pay"
        window.minSize = NSSize(width: 960, height: 600)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SafefyMainWindow")
        window.contentView = NSHostingView(rootView: BrowserView(model: model))
        window.center()
        makeMenus()
        showWindow()
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: "keepRunning")
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return true
    }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings?.title = "Ajustes da Safefy Pay"
            settings?.isReleasedWhenClosed = false
            settings?.contentView = NSHostingView(rootView: PreferencesView(model: model))
            settings?.center()
        }
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.refreshPermission()
    }
    @objc func reloadPage() { model.webView.reload() }
    @objc func requestNotices() { model.requestNotices() }
    @objc func testNotice() { model.testNotice() }

    private func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
    private func makeMenus() {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(item("Abrir Safefy Pay", #selector(showWindow), "0"))
        appMenu.addItem(item("Ajustes…", #selector(showSettings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ocultar Safefy Pay", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Encerrar Safefy Pay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let root = NSMenuItem(); root.submenu = appMenu; main.addItem(root)
        let edit = NSMenu(title: "Editar")
        for (title, action, key) in [("Desfazer", "undo:", "z"), ("Recortar", "cut:", "x"), ("Copiar", "copy:", "c"), ("Colar", "paste:", "v"), ("Selecionar tudo", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        let view = NSMenu(title: "Visualizar")
        view.addItem(item("Recarregar", #selector(reloadPage), "r"))
        view.addItem(withTitle: "Fechar janela", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let viewItem = NSMenuItem(); viewItem.submenu = view; main.addItem(viewItem)
        NSApp.mainMenu = main
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let iconURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"), let icon = NSImage(contentsOf: iconURL) {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "creditcard.fill", accessibilityDescription: "Safefy Pay")
        }
        statusItem.button?.image?.accessibilityDescription = "Safefy Pay"
        statusItem.button?.toolTip = "Safefy Pay — continua ativa com a janela fechada"
        let menu = NSMenu()
        menu.addItem(item("Abrir Safefy Pay", #selector(showWindow)))
        menu.addItem(item("Ativar notificações…", #selector(requestNotices)))
        menu.addItem(item("Enviar notificação de teste", #selector(testNotice)))
        menu.addItem(item("Ajustes…", #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Encerrar Safefy Pay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
}

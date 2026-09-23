import AppKit
import WebKit

@MainActor
final class SplashWindow {
    private var window: NSWindow?
    private var webView: WKWebView?

    func show(state: String) {
        let size = NSSize(width: 160, height: 160)
        let webView = WKWebView(frame: NSRect(origin: .zero, size: size))
        webView.setValue(false, forKey: "drawsBackground")
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Splash"),
              let directory = Bundle.main.url(forResource: "Splash", withExtension: nil) else { return }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "state", value: state)]
        guard let finalURL = components?.url else { return }
        webView.loadFileURL(finalURL, allowingReadAccessTo: directory)

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        self.webView = webView
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        webView = nil
    }
}

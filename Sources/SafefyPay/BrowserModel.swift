import AppKit
import Combine
import WebKit
import UserNotifications

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKDownloadDelegate, UNUserNotificationCenterDelegate {
    @Published var error: String?
    @Published var message: String?
    @Published var bridgeConnected = false
    @Published var permissionStatus = "Notificações ainda não autorizadas"
    var openWindow: (() -> Void)?
    private(set) var webView: WKWebView!
    private var recent = RecentNotices()
    private var scope: String?
    private var lastHeartbeat: Date?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var permissionGranted = false
    private var popupWindow: NSWindow?
    private var popupWebView: WKWebView?
    private var popupCloseObserver: NSObjectProtocol?

    override init() {
        super.init()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.add(self, name: "safefyMac")
        configuration.userContentController.addUserScript(WKUserScript(source: """
        if (window.location.origin === 'https://app.safefypay.com.br' && window === window.top) {
            Object.defineProperty(window, 'safefyMac', {
                value: Object.freeze({version: 1}), writable: false, configurable: false
            });
        }
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
        refreshPermission()
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                         reason: "Receber eventos da Safefy Pay enquanto o aplicativo está aberto")
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let last = self.lastHeartbeat, Date().timeIntervalSince(last) > 65 {
                    self.bridgeConnected = false
                }
            }
        }
        loadHome()
    }
    func stop() {
        timer?.invalidate()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
    }
    func loadHome() { error = nil; webView.load(URLRequest(url: BridgePolicy.home)) }

    func refreshPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.permissionGranted = settings.authorizationStatus == .authorized
                self.permissionStatus = self.permissionGranted ? "Notificações permitidas pelo macOS" : "Permita notificações nos Ajustes do Sistema"
            }
        }
    }
    func requestNotices() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.refreshPermission()
                self.message = error?.localizedDescription ?? (granted
                    ? "Notificações permitidas. Os avisos reais começam quando a integração do painel estiver conectada."
                    : "Ative Safefy Pay em Ajustes do Sistema → Notificações.")
            }
        }
    }
    func testNotice() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.refreshPermission()
                guard granted else { self.message = error?.localizedDescription ?? "Permita notificações nos Ajustes do Sistema."; return }
                let content = UNMutableNotificationContent()
                content.title = "Safefy Pay"
                content.body = "Tudo pronto: este é um aviso de teste do seu Mac."
                if UserDefaults.standard.bool(forKey: "noticeSound") { content.sound = .default }
                let request = UNNotificationRequest(identifier: "test-" + UUID().uuidString, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { Task { @MainActor in self.message = error.localizedDescription } }
                }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.webView === webView, message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host == BridgePolicy.home.host,
              [0, 443].contains(message.frameInfo.securityOrigin.port),
              BridgePolicy.trusted(webView.url),
              webView.url?.path.hasPrefix("/panel/") == true,
              let body = message.body as? [String: Any], body["version"] as? Int == 1 else { return }
        if body["type"] as? String == "state" {
            guard let newScope = body["scope"] as? String, newScope.count <= 512,
                  let connected = body["connected"] as? Bool else { return }
            if newScope != scope {
                clearSessionNotices()
                scope = newScope.isEmpty ? nil : newScope
            }
            lastHeartbeat = Date()
            bridgeConnected = connected && scope != nil
            return
        }
        guard bridgeConnected, let scope, body["scope"] as? String == scope,
              let lastHeartbeat, Date().timeIntervalSince(lastHeartbeat) < 65,
              let notice = BridgeNotice(body), recent.accept(scope + ":" + notice.id) else { return }
        guard permissionGranted else { refreshPermission(); return }
        let content = UNMutableNotificationContent()
        let hide = UserDefaults.standard.bool(forKey: "privateNotices")
        content.title = hide ? "Safefy Pay" : notice.title
        content.body = hide ? "Você recebeu uma nova atualização. Abra a Safefy Pay para conferir." : notice.body
        if UserDefaults.standard.bool(forKey: "noticeSound") { content.sound = .default }
        content.userInfo = ["destination": notice.destination.absoluteString, "scope": scope]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: scope + ":" + notice.id, content: content, trigger: nil)) { error in
            if let error { Task { @MainActor in self.message = "Não foi possível mostrar o aviso: " + error.localizedDescription } }
        }
    }

    private func clearSessionNotices() {
        recent.reset()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        error = nil
        bridgeConnected = false
        lastHeartbeat = nil
        scope = nil
        clearSessionNotices()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView, !Self.isCancellation(error) else { return }
        self.error = error.localizedDescription
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView, !Self.isCancellation(error) else { return }
        self.error = error.localizedDescription
    }
    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else { return }
        bridgeConnected = false
        error = "O conteúdo foi interrompido. Reabra o painel para continuar."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if webView === popupWebView {
            if BridgePolicy.trusted(url) {
                decisionHandler(.allow)
            } else if url.scheme == "https" {
                decisionHandler(.cancel)
                closePopup()
                openExternally(url)
            } else {
                decisionHandler(.cancel)
            }
            return
        }
        if navigationAction.shouldPerformDownload && (BridgePolicy.trusted(url) || url.scheme == "blob") {
            decisionHandler(.download); return
        }
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(url.scheme == "https" || url.scheme == "about" ? .allow : .cancel); return
        }
        if BridgePolicy.trusted(url) { decisionHandler(.allow); return }
        decisionHandler(.cancel)
        if ["https", "mailto"].contains(url.scheme ?? "") {
            openExternally(url)
        } else {
            message = "Esta etapa abriu um endereço externo. Para entrar no app, use e-mail e senha."
        }
    }
    private func openExternally(_ url: URL) {
        NSWorkspace.shared.open(url)
        message = "Abrimos essa etapa no seu navegador padrão — ele já deve estar com sua conta Google conectada. Depois de concluir, volte aqui e entre com e-mail e senha (o retorno automático para o app ainda não está disponível)."
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        closePopup()
        let width = windowFeatures.width?.doubleValue ?? 480
        let height = windowFeatures.height?.doubleValue ?? 640
        let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        let window = NSWindow(contentRect: popup.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Entrar"
        window.contentView = popup
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        popupCloseObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.clearPopup() }
        }
        popupWindow = window
        popupWebView = popup
        return popup
    }
    private func clearPopup() {
        if let popupCloseObserver { NotificationCenter.default.removeObserver(popupCloseObserver) }
        popupCloseObserver = nil
        popupWebView = nil
        popupWindow = nil
    }
    private func closePopup() {
        popupWindow?.close()
        clearPopup()
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (suggestedFilename as NSString).lastPathComponent
        panel.begin { result in completionHandler(result == .OK ? panel.url : nil) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { message = "Download interrompido: " + error.localizedDescription }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard BridgePolicy.trusted(frame.request.url) else { completionHandler(nil); return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.begin { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = "Safefy Pay"; alert.informativeText = message
        alert.runModal(); completionHandler()
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert(); alert.messageText = "Safefy Pay"; alert.informativeText = message
        alert.addButton(withTitle: "Confirmar"); alert.addButton(withTitle: "Cancelar")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let destination = response.notification.request.content.userInfo["destination"] as? String
        let noticeScope = response.notification.request.content.userInfo["scope"] as? String
        Task { @MainActor in
            self.openWindow?()
            if let destination, let noticeScope, noticeScope == self.scope {
                self.webView.load(URLRequest(url: BridgePolicy.destination(destination)))
            }
            completionHandler()
        }
    }
}

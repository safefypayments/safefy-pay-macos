import SwiftUI
import WebKit

struct WebContainer: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @ObservedObject var model: BrowserModel
    var body: some View {
        ZStack {
            WebContainer(webView: model.webView)
            if let error = model.error {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                    Text("Não foi possível abrir a Safefy Pay").font(.title3.bold())
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Tentar novamente") { model.loadHome() }.buttonStyle(.borderedProminent)
                }.padding(32).frame(maxWidth: 480).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Safefy Pay", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}

private func hugeIcon(_ name: String) -> NSImage {
    guard let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons"),
          let image = NSImage(contentsOf: url) else { return NSImage() }
    image.isTemplate = true
    return image
}

struct HugeIcon: View {
    let name: String
    var size: CGFloat = 18
    var body: some View {
        Image(nsImage: hugeIcon(name))
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(.secondary)
    }
}

struct PreferencesView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var updater: UpdaterViewModel
    @AppStorage("keepRunning") private var keepRunning = true
    @AppStorage("privateNotices") private var privateNotices = true
    @AppStorage("noticeSound") private var sound = true
    var body: some View {
        Form {
            Section("Funcionamento") {
                Toggle(isOn: $keepRunning) {
                    Label { Text("Continuar ativo ao fechar a janela") } icon: { HugeIcon(name: "AppWindowMac") }
                }
                Text("O app precisa continuar aberto e conectado para receber novos avisos. Ao encerrar com ⌘Q, eles param.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Atualizações") {
                Toggle(isOn: $updater.automaticallyChecksForUpdates) {
                    Label { Text("Verificar atualizações automaticamente") } icon: { HugeIcon(name: "ArrowReloadHorizontal") }
                }
                Button("Verificar agora") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            Section("Notificações") {
                Label { Text(model.permissionStatus) } icon: { HugeIcon(name: "Notification03") }
                    .foregroundStyle(.secondary)
                Toggle(isOn: $privateNotices) {
                    Label { Text("Ocultar detalhes financeiros nos avisos") } icon: { HugeIcon(name: "EyeOff") }
                }
                Toggle(isOn: $sound) {
                    Label { Text("Reproduzir som") } icon: { HugeIcon(name: "VolumeHigh") }
                }
                HStack {
                    Button("Permitir notificações") { model.requestNotices() }
                    Button("Testar") { model.testNotice() }
                }
                Text("O teste verifica o macOS. Avisos reais dependem da integração do painel estar publicada.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).padding(8).frame(width: 540, height: 520)
    }
}

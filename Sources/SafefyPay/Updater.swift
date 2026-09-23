import Combine
import Sparkle

@MainActor
final class UpdaterViewModel: ObservableObject {
    private let updater: SPUUpdater
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates: Bool {
        didSet { updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    init(updater: SPUUpdater) {
        self.updater = updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() { updater.checkForUpdates() }
}

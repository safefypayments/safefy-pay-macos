import Foundation

enum BridgePolicy {
    static let home = URL(string: "https://app.safefypay.com.br/")!

    static func trusted(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && url.host == home.host
            && (url.port == nil || url.port == 443)
            && url.user == nil && url.password == nil
    }

    static func destination(_ raw: String?) -> URL {
        guard let raw, let url = URL(string: raw, relativeTo: home)?.absoluteURL,
              trusted(url), url.path.hasPrefix("/panel/") else {
            return home.appendingPathComponent("panel/notifications")
        }
        return url
    }
}

struct BridgeNotice {
    let id: String
    let title: String
    let body: String
    let destination: URL

    init?(_ message: [String: Any]) {
        guard message["version"] as? Int == 1,
              message["type"] as? String == "notification",
              let id = message["id"] as? String, !id.isEmpty, id.count <= 128,
              let title = message["title"] as? String, !title.isEmpty, title.count <= 256,
              let body = message["body"] as? String, body.count <= 4096 else { return nil }
        self.id = id
        self.title = title
        self.body = body
        self.destination = BridgePolicy.destination(message["actionUrl"] as? String)
    }
}

struct RecentNotices {
    private var entries: [String: Date] = [:]
    mutating func accept(_ id: String, now: Date = Date()) -> Bool {
        entries = entries.filter { now.timeIntervalSince($0.value) < 3600 }
        guard entries[id] == nil else { return false }
        if entries.count >= 1000, let oldest = entries.min(by: { $0.value < $1.value })?.key {
            entries.removeValue(forKey: oldest)
        }
        entries[id] = now
        return true
    }
    mutating func reset() { entries.removeAll() }
}

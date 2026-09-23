import XCTest
@testable import SafefyPay

final class BridgePolicyTests: XCTestCase {
    func testOnlyExactSecureOriginIsTrusted() {
        XCTAssertTrue(BridgePolicy.trusted(URL(string: "https://app.safefypay.com.br/panel/dashboard")))
        for raw in ["http://app.safefypay.com.br", "https://app.safefypay.com.br.evil.test", "https://evil.test", "file:///tmp/test", "https://app.safefypay.com.br:444", "https://user@app.safefypay.com.br"] {
            XCTAssertFalse(BridgePolicy.trusted(URL(string: raw)), raw)
        }
    }
    func testNotificationLinksCannotEscapePanel() {
        for raw in ["//evil.test/", "javascript:alert(1)", "https://evil.test/panel/", "/api/auth/signout", "/"] {
            XCTAssertEqual(BridgePolicy.destination(raw).path, "/panel/notifications")
        }
        XCTAssertEqual(BridgePolicy.destination("/panel/dashboard").path, "/panel/dashboard")
    }
    func testPayloadValidation() {
        var payload: [String: Any] = ["version": 1, "type": "notification", "id": "event", "title": "Payment", "body": "Update"]
        XCTAssertNotNil(BridgeNotice(payload))
        payload["body"] = String(repeating: "x", count: 4097)
        XCTAssertNil(BridgeNotice(payload))
        payload["body"] = "Update"; payload["version"] = 2
        XCTAssertNil(BridgeNotice(payload))
    }
    func testDuplicateEventsExpireAndReset() {
        var notices = RecentNotices()
        let now = Date()
        XCTAssertTrue(notices.accept("a", now: now))
        XCTAssertFalse(notices.accept("a", now: now.addingTimeInterval(10)))
        XCTAssertTrue(notices.accept("a", now: now.addingTimeInterval(3601)))
        notices.reset()
        XCTAssertTrue(notices.accept("a", now: now.addingTimeInterval(3602)))
    }
}

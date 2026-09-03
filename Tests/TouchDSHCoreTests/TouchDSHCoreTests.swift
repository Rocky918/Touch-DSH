import XCTest
@testable import TouchDSHCore

final class TouchDSHCoreTests: XCTestCase {
    func testProcessIdentityAcceptsOnlyCurrentUsersDSHWeb() {
        XCTAssertTrue(DSHProcessIdentity.isOwnedDSHWeb(
            command: "node /example/@deepseek-ai/dsh/lib/bin.js web",
            processUser: "alice",
            currentUser: "alice"
        ))
        XCTAssertFalse(DSHProcessIdentity.isOwnedDSHWeb(
            command: "node /example/@deepseek-ai/dsh/lib/bin.js web",
            processUser: "root",
            currentUser: "alice"
        ))
        XCTAssertFalse(DSHProcessIdentity.isOwnedDSHWeb(
            command: "node server.js",
            processUser: "alice",
            currentUser: "alice"
        ))
    }

    func testReducerStatePriorityAndRecovery() {
        var reducer = DSHEventReducer()
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: false, unhealthy: false), .idle)
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: true, unhealthy: false), .working)

        reducer.consume(["rpcId": "r1", "payload": ["type": "approval/requested", "approvalId": "a1"]])
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: true, unhealthy: false), .waiting)
        reducer.consume(["payload": ["type": "approval/resolved", "approvalId": "a1"]])
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: true, unhealthy: false), .working)

        reducer.consume(["payload": [
            "type": "session/event", "sessionId": "s1",
            "event": ["type": "turn/end", "data": ["reason": ["kind": "blocked"]]]
        ]])
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: false, unhealthy: false), .error)
        reducer.consume(["payload": [
            "type": "session/event", "sessionId": "s1",
            "event": ["type": "turn/start", "data": [:]]
        ]])
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: true, unhealthy: false), .working)

        reducer.consume(["rpcId": "q1", "payload": ["type": "question/requested", "sessionId": "s1"]])
        XCTAssertEqual(reducer.light(serverOnline: true, anyRunning: true, unhealthy: false), .waiting)
        XCTAssertEqual(reducer.light(serverOnline: false, anyRunning: true, unhealthy: false), .offline)
    }
}

import XCTest
@testable import StabilizerCore

final class DiagnosticsTests: XCTestCase {
    private let weakFiveGHz = LinkSnapshot(networkName: "Home", interfaceName: "en0", rssi: -78,
                                         noise: -91, transmitRate: 65, channel: 149, band: .fiveGHz)

    func testPingParsesMacOSSummary() {
        let text = "3 packets transmitted, 2 packets received, 33.3% packet loss\nround-trip min/avg/max/stddev = 12.1/24.5/36.9/10.0 ms"
        XCTAssertEqual(PingResult.parse(text), PingResult(lossPercent: 33.3, averageMS: 24.5))
        XCTAssertNil(PingResult.parse("ping: cannot resolve example.com"))
    }

    func testChannelLoadCountsAdjacentTwoGHzAndSameFiveGHz() {
        let twoGHz = LinkSnapshot(networkName: "Home", interfaceName: "en0", rssi: -60,
                                  noise: -90, transmitRate: 100, channel: 6, band: .twoGHz)
        let neighbors = [
            NearbyNetwork(id: "a", name: "A", rssi: -50, channel: 6, band: .twoGHz),
            NearbyNetwork(id: "b", name: "B", rssi: -50, channel: 11, band: .twoGHz),
            NearbyNetwork(id: "c", name: "C", rssi: -50, channel: 10, band: .twoGHz)
        ]
        XCTAssertEqual(Diagnostics.channelLoad(for: twoGHz, nearby: neighbors), 5.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(Diagnostics.channelLoad(for: weakFiveGHz, nearby: neighbors), 0)
    }

    func testGuidanceSeparatesWeakLinkFromDNSFailure() {
        let probe = ProbeSnapshot(internetReachable: true, dnsReachable: false,
                                  latencyMS: 20, packetLossPercent: 0)
        let advice = Diagnostics.guidance(link: weakFiveGHz, probe: probe, nearby: [])
        XCTAssertTrue(advice.contains { $0.contains("2.4 GHz") })
        XCTAssertTrue(advice.contains { $0.contains("DNS settings") })
    }

    func testRecoveryRequiresRepeatedFailureAndCooldown() {
        let now = Date()
        let failed = ProbeSnapshot(internetReachable: false, dnsReachable: false,
                                   latencyMS: nil, packetLossPercent: 100)
        XCTAssertFalse(Diagnostics.shouldReconnect(link: weakFiveGHz, probe: failed,
                                                    consecutiveFailures: 2, lastAttempt: nil, now: now))
        XCTAssertTrue(Diagnostics.shouldReconnect(link: weakFiveGHz, probe: failed,
                                                   consecutiveFailures: 3, lastAttempt: nil, now: now))
        XCTAssertFalse(Diagnostics.shouldReconnect(link: weakFiveGHz, probe: failed,
                                                    consecutiveFailures: 3, lastAttempt: now, now: now))
        XCTAssertTrue(Diagnostics.shouldReconnect(link: weakFiveGHz, probe: failed,
                                                   consecutiveFailures: 3,
                                                   lastAttempt: now.addingTimeInterval(-601), now: now))
    }
}

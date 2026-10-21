import XCTest
@testable import StabilizerCore

final class PresenceTests: XCTestCase {
    func testWiFiChangeRequiresSustainedDeviation() {
        XCTAssertFalse(PresenceAnalyzer.wifiChanged(samples: Array(repeating: -70, count: 20)))
        XCTAssertTrue(PresenceAnalyzer.wifiChanged(samples:
            Array(repeating: -70, count: 15) + Array(repeating: -80, count: 5)))
    }

    func testOldBluetoothCluesExpire() {
        let result = PresenceAnalyzer.assess(bluetooth: [
            BluetoothClue(rssi: -50, sightings: 4, ageSeconds: 31)
        ], wifiSamples: [])
        XCTAssertEqual(result.nearbySignalCount, 0)
    }

    func testCameraEvidenceIsDirectButBluetoothIsNot() {
        let radio = PresenceAnalyzer.assess(bluetooth: [
            BluetoothClue(rssi: -58, sightings: 3, ageSeconds: 2)
        ], wifiSamples: [])
        XCTAssertTrue(PresenceFusion.combine(peopleInCamera: 1, recentSpeechConfidence: nil,
                                              radio: radio).directEvidence)
        XCTAssertFalse(PresenceFusion.combine(peopleInCamera: nil, recentSpeechConfidence: nil,
                                               radio: radio).directEvidence)
    }
}

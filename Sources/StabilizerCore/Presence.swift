import Foundation

public struct BluetoothClue: Equatable {
    public let rssi: Int
    public let sightings: Int
    public let ageSeconds: TimeInterval

    public init(rssi: Int, sightings: Int, ageSeconds: TimeInterval) {
        self.rssi = rssi
        self.sightings = sightings
        self.ageSeconds = ageSeconds
    }
}

public struct PresenceAssessment: Equatable {
    public let nearbySignalCount: Int
    public let strongSignalCount: Int
    public let wifiChanged: Bool
    public let evidenceScore: Int
    public let message: String

    public init(nearbySignalCount: Int, strongSignalCount: Int, wifiChanged: Bool,
                evidenceScore: Int, message: String) {
        self.nearbySignalCount = nearbySignalCount
        self.strongSignalCount = strongSignalCount
        self.wifiChanged = wifiChanged
        self.evidenceScore = evidenceScore
        self.message = message
    }
}

public enum PresenceAnalyzer {
    public static func wifiChanged(samples: [Int]) -> Bool {
        guard samples.count >= 15 else { return false }
        let baseline = samples.dropLast(5).suffix(25).sorted()
        guard !baseline.isEmpty else { return false }
        let median = baseline[baseline.count / 2]
        return samples.suffix(5).filter { abs($0 - median) >= 6 }.count >= 3
    }

    public static func assess(bluetooth: [BluetoothClue], wifiSamples: [Int]) -> PresenceAssessment {
        let recent = bluetooth.filter { $0.ageSeconds <= 30 && $0.ageSeconds >= 0 && $0.rssi >= -100 && $0.rssi < 0 }
        let nearby = recent.filter { $0.rssi >= -80 }
        let strong = nearby.filter { $0.rssi >= -65 }
        let repeated = nearby.filter { $0.sightings >= 2 }
        let changed = wifiChanged(samples: wifiSamples)
        let score = min(85, nearby.count * 18 + strong.count * 12 + repeated.count * 10 + (changed ? 10 : 0))

        let message: String
        if !nearby.isEmpty {
            message = "Nearby Bluetooth signals detected"
        } else if changed {
            message = "Wi-Fi signal changed; cause unknown"
        } else {
            message = "No nearby radio clues detected"
        }
        return PresenceAssessment(nearbySignalCount: nearby.count, strongSignalCount: strong.count,
                                  wifiChanged: changed, evidenceScore: score, message: message)
    }
}

public struct CombinedPresence: Equatable {
    public let title: String
    public let explanation: String
    public let directEvidence: Bool

    public init(title: String, explanation: String, directEvidence: Bool) {
        self.title = title
        self.explanation = explanation
        self.directEvidence = directEvidence
    }
}

public enum PresenceFusion {
    public static func combine(peopleInCamera: Int?, recentSpeechConfidence: Double?,
                               radio: PresenceAssessment) -> CombinedPresence {
        if let count = peopleInCamera, count > 0 {
            return CombinedPresence(title: count == 1 ? "Person in camera view" : "People in camera view",
                                    explanation: "On-device camera analysis found \(count) person\(count == 1 ? "" : "s") in the visible scene.",
                                    directEvidence: true)
        }
        if let confidence = recentSpeechConfidence, confidence >= 0.55 {
            return CombinedPresence(title: "Speech-like sound detected",
                                    explanation: "The microphone heard a sound classified as speech. A speaker or recording can cause this too.",
                                    directEvidence: false)
        }
        if radio.nearbySignalCount > 0 && radio.wifiChanged {
            return CombinedPresence(title: "Indirect nearby activity",
                                    explanation: "Bluetooth signals and a Wi-Fi change were observed. Neither proves a person is nearby.",
                                    directEvidence: false)
        }
        if radio.nearbySignalCount > 0 {
            return CombinedPresence(title: "Nearby devices detected",
                                    explanation: "Bluetooth advertisements were received. Devices are not a count of people.",
                                    directEvidence: false)
        }
        if radio.wifiChanged {
            return CombinedPresence(title: "Wi-Fi signal changed",
                                    explanation: "The cause could be motion, interference, or normal radio variation.",
                                    directEvidence: false)
        }
        if peopleInCamera == 0 {
            return CombinedPresence(title: "No person in camera view",
                                    explanation: "The camera sees only what is in front of it. People elsewhere may still be nearby.",
                                    directEvidence: false)
        }
        return CombinedPresence(title: "No direct result yet",
                                explanation: "Start the camera, microphone, or radio scan to gather local evidence.",
                                directEvidence: false)
    }
}

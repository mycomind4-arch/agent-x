import Foundation
import StabilizerCore

let summary = "3 packets transmitted, 2 packets received, 33.3% packet loss\nround-trip min/avg/max/stddev = 12.1/24.5/36.9/10.0 ms"
precondition(PingResult.parse(summary) == PingResult(lossPercent: 33.3, averageMS: 24.5))
precondition(PingResult.parse("unrecognized ping output") == nil)

let weakLink = LinkSnapshot(networkName: "Home", interfaceName: "en0", rssi: -78,
                            noise: -91, transmitRate: 65, channel: 149, band: .fiveGHz)
let dnsFailure = ProbeSnapshot(internetReachable: true, dnsReachable: false,
                               latencyMS: 20, packetLossPercent: 0)
let advice = Diagnostics.guidance(link: weakLink, probe: dnsFailure, nearby: [])
precondition(advice.contains { $0.contains("2.4 GHz") })
precondition(advice.contains { $0.contains("DNS settings") })

let twoGHz = LinkSnapshot(networkName: "Home", interfaceName: "en0", rssi: -60,
                          noise: -90, transmitRate: 100, channel: 6, band: .twoGHz)
let neighbors = [
    NearbyNetwork(id: "a", name: "A", rssi: -50, channel: 6, band: .twoGHz),
    NearbyNetwork(id: "b", name: "B", rssi: -50, channel: 11, band: .twoGHz)
]
precondition(abs(Diagnostics.channelLoad(for: twoGHz, nearby: neighbors) - (5.0 / 6.0)) < 0.001)
precondition(Diagnostics.channelLoad(for: weakLink, nearby: neighbors) == 0)

let now = Date()
let failed = ProbeSnapshot(internetReachable: false, dnsReachable: false,
                           latencyMS: nil, packetLossPercent: 100)
precondition(!Diagnostics.shouldReconnect(link: weakLink, probe: failed,
                                           consecutiveFailures: 2, lastAttempt: nil, now: now))
precondition(Diagnostics.shouldReconnect(link: weakLink, probe: failed,
                                          consecutiveFailures: 3, lastAttempt: nil, now: now))
precondition(!Diagnostics.shouldReconnect(link: weakLink, probe: failed,
                                           consecutiveFailures: 3, lastAttempt: now, now: now))

let stable = Array(repeating: -70, count: 20)
let changed = Array(repeating: -70, count: 15) + Array(repeating: -80, count: 5)
precondition(!PresenceAnalyzer.wifiChanged(samples: stable))
precondition(PresenceAnalyzer.wifiChanged(samples: changed))
let radio = PresenceAnalyzer.assess(bluetooth: [BluetoothClue(rssi: -58, sightings: 3, ageSeconds: 2)],
                                    wifiSamples: stable)
precondition(radio.nearbySignalCount == 1 && radio.strongSignalCount == 1)
precondition(PresenceFusion.combine(peopleInCamera: 1, recentSpeechConfidence: nil,
                                    radio: radio).directEvidence)
precondition(!PresenceFusion.combine(peopleInCamera: nil, recentSpeechConfidence: nil,
                                     radio: radio).directEvidence)
print("Core diagnostic self-test passed (13 checks).")

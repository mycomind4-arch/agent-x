import Foundation

public enum WiFiBand: String, Codable, Hashable {
    case twoGHz = "2.4 GHz"
    case fiveGHz = "5 GHz"
    case sixGHz = "6 GHz"
    case unknown = "Unknown"
}

public struct LinkSnapshot: Codable, Equatable {
    public let date: Date
    public let networkName: String?
    public let interfaceName: String
    public let rssi: Int
    public let noise: Int?
    public let transmitRate: Double
    public let channel: Int?
    public let band: WiFiBand

    public init(date: Date = Date(), networkName: String?, interfaceName: String, rssi: Int,
                noise: Int?, transmitRate: Double, channel: Int?, band: WiFiBand) {
        self.date = date
        self.networkName = networkName
        self.interfaceName = interfaceName
        self.rssi = rssi
        self.noise = noise
        self.transmitRate = transmitRate
        self.channel = channel
        self.band = band
    }

    public var snr: Int? { noise.map { rssi - $0 } }
}

public struct NearbyNetwork: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let rssi: Int
    public let channel: Int
    public let band: WiFiBand

    public init(id: String, name: String, rssi: Int, channel: Int, band: WiFiBand) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.channel = channel
        self.band = band
    }
}

public struct ProbeSnapshot: Equatable {
    public let date: Date
    public let internetReachable: Bool
    public let dnsReachable: Bool
    public let latencyMS: Double?
    public let packetLossPercent: Double?
    public let note: String?

    public init(date: Date = Date(), internetReachable: Bool, dnsReachable: Bool,
                latencyMS: Double?, packetLossPercent: Double?, note: String? = nil) {
        self.date = date
        self.internetReachable = internetReachable
        self.dnsReachable = dnsReachable
        self.latencyMS = latencyMS
        self.packetLossPercent = packetLossPercent
        self.note = note
    }
}

public enum SignalQuality: String, Equatable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    case veryWeak = "Very weak"
    case unusable = "Unusable"

    // RSSI bands adapted from Sir-Goose/live-signal (MIT), commit 73a6988.
    public static func from(rssi: Int) -> SignalQuality {
        switch rssi {
        case ...(-81): return .unusable
        case -80 ... -71: return .veryWeak
        case -70 ... -61: return .weak
        case -60 ... -51: return .fair
        case -50 ... -31: return .good
        default: return .excellent
        }
    }

    public var score: Double {
        switch self {
        case .excellent: return 1
        case .good: return 0.85
        case .fair: return 0.65
        case .weak: return 0.4
        case .veryWeak: return 0.2
        case .unusable: return 0.05
        }
    }
}

public struct PingResult: Equatable {
    public let lossPercent: Double
    public let averageMS: Double?

    public init(lossPercent: Double, averageMS: Double?) {
        self.lossPercent = lossPercent
        self.averageMS = averageMS
    }

    public static func parse(_ output: String) -> PingResult? {
        guard let loss = firstMatch(#"([0-9]+(?:\.[0-9]+)?)% packet loss"#, in: output).flatMap(Double.init) else {
            return nil
        }
        let average = firstMatch(#"(?:round-trip|rtt) min/avg/max(?:/stddev|/mdev)? = [0-9.]+/([0-9.]+)"#, in: output).flatMap(Double.init)
        return PingResult(lossPercent: loss, averageMS: average)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

public enum Diagnostics {
    public static func channelLoad(for current: LinkSnapshot, nearby: [NearbyNetwork]) -> Double {
        guard let channel = current.channel else { return 0 }
        return nearby.filter { $0.band == current.band }.reduce(0) { total, network in
            let separation = abs(network.channel - channel)
            let overlap: Double
            if current.band == .twoGHz {
                overlap = max(0, 1 - Double(separation) / 5)
            } else {
                overlap = separation == 0 ? 1 : 0
            }
            let strength = max(0.1, min(1, Double(network.rssi + 100) / 60))
            return total + overlap * strength
        }
    }

    public static func guidance(link: LinkSnapshot?, probe: ProbeSnapshot?, nearby: [NearbyNetwork]) -> [String] {
        guard let link else { return ["Connect to Wi-Fi to start monitoring."] }
        var advice: [String] = []
        let quality = SignalQuality.from(rssi: link.rssi)

        if quality == .veryWeak || quality == .unusable {
            advice.append("The signal is very weak. Move the Mac or router closer, or place a mesh node between them.")
        } else if quality == .weak {
            advice.append("Signal strength is marginal. A small change in router or Mac placement may help.")
        }

        if (quality == .weak || quality == .veryWeak || quality == .unusable),
           link.band == .fiveGHz || link.band == .sixGHz {
            advice.append("At this distance, try your router’s 2.4 GHz network for a steadier connection.")
        }

        if let snr = link.snr, snr < 15 {
            advice.append("The signal is close to the noise floor. Check for interference or try another router channel.")
        }

        if !nearby.isEmpty && channelLoad(for: link, nearby: nearby) >= 2 {
            advice.append("Several nearby networks overlap this channel. Try a less crowded channel in your router settings.")
        }

        if let probe {
            if probe.internetReachable && !probe.dnsReachable {
                advice.append("The internet responds, but name lookup failed. Check your DNS settings.")
            } else if !probe.internetReachable && quality.score >= 0.65 {
                advice.append("Wi-Fi signal looks usable, but the internet probe failed. Check the router or internet service.")
            }
            if let loss = probe.packetLossPercent, loss >= 10 {
                advice.append("The internet probe lost \(Int(loss))% of its test packets. Repeat the test to confirm the pattern.")
            }
        }

        if advice.isEmpty {
            advice.append("No clear problem detected. Keep monitoring during the times the connection feels unstable.")
        }
        return advice
    }

    public static func shouldReconnect(link: LinkSnapshot?, probe: ProbeSnapshot?, consecutiveFailures: Int,
                                       lastAttempt: Date?, now: Date) -> Bool {
        guard let link, let probe, consecutiveFailures >= 3,
              link.rssi <= -75, !probe.internetReachable else { return false }
        return lastAttempt.map { now.timeIntervalSince($0) >= 600 } ?? true
    }
}

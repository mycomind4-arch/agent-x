import CoreWLAN
import Foundation
import StabilizerCore

enum WiFiReader {
    static func snapshot() -> LinkSnapshot? {
        guard let interface = CWWiFiClient.shared().interface(),
              interface.powerOn(),
              let channel = interface.wlanChannel() else { return nil }
        let rssi = interface.rssiValue()
        guard rssi < 0 else { return nil }
        let noise = interface.noiseMeasurement()
        return LinkSnapshot(
            networkName: interface.ssid(),
            interfaceName: interface.interfaceName ?? "Wi-Fi",
            rssi: rssi,
            noise: noise < 0 ? noise : nil,
            transmitRate: interface.transmitRate(),
            channel: channel.channelNumber,
            band: band(for: channel.channelBand.rawValue)
        )
    }

    static func scan() throws -> [NearbyNetwork] {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else { return [] }
        return try interface.scanForNetworks(withName: nil)
            .sorted { $0.rssiValue > $1.rssiValue }
            .enumerated()
            .compactMap { index, network in
                guard let channel = network.wlanChannel else { return nil }
                return NearbyNetwork(
                    id: "\(index)-\(channel.channelNumber)",
                    name: network.ssid ?? "Name hidden by macOS",
                    rssi: network.rssiValue,
                    channel: channel.channelNumber,
                    band: band(for: channel.channelBand.rawValue)
                )
            }
    }

    static func reconnect() {
        CWWiFiClient.shared().interface()?.disassociate()
    }

    private static func band(for rawValue: Int) -> WiFiBand {
        switch rawValue {
        case 1: return .twoGHz
        case 2: return .fiveGHz
        case 3: return .sixGHz
        default: return .unknown
        }
    }
}

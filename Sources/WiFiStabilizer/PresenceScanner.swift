import CoreBluetooth
import Foundation
import StabilizerCore

final class PresenceScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var isScanning = false
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var status = "Ready to scan"
    @Published private(set) var assessment = PresenceAnalyzer.assess(bluetooth: [], wifiSamples: [])

    private struct Signal {
        var rssi: Int
        var sightings: Int
        var lastSeen: Date
    }

    private var manager: CBCentralManager?
    private var timer: Timer?
    private var deadline: Date?
    private var signals: [UUID: Signal] = [:]
    private var wifiSamples: [Int] = []

    func start() {
        guard !isScanning else { return }
        signals.removeAll()
        wifiSamples.removeAll()
        assessment = PresenceAnalyzer.assess(bluetooth: [], wifiSamples: [])
        secondsRemaining = 60
        deadline = Date().addingTimeInterval(60)
        isScanning = true
        status = "Starting Bluetooth scan…"
        manager = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        manager?.stopScan()
        manager?.delegate = nil
        manager = nil
        timer?.invalidate()
        timer = nil
        deadline = nil
        secondsRemaining = 0
        isScanning = false
        if status == "Scanning nearby Bluetooth signals…" || status == "Starting Bluetooth scan…" {
            status = "Scan complete"
        }
        updateAssessment()
        signals.removeAll() // Identifiers are used only to deduplicate this scan.
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isScanning else { return }
        switch central.state {
        case .poweredOn:
            status = "Scanning nearby Bluetooth signals…"
            central.scanForPeripherals(withServices: nil,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .poweredOff:
            status = "Bluetooth is turned off."
            stop()
        case .unauthorized:
            status = "Bluetooth access was not allowed. Check Privacy & Security settings."
            stop()
        case .unsupported:
            status = "Bluetooth Low Energy scanning is unavailable on this Mac."
            stop()
        case .resetting, .unknown:
            status = "Waiting for Bluetooth…"
        @unknown default:
            status = "Bluetooth state is unavailable."
            stop()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard isScanning else { return }
        let rssi = RSSI.intValue
        guard rssi >= -100 && rssi < 0 else { return }
        let id = peripheral.identifier
        let previous = signals[id]
        signals[id] = Signal(rssi: rssi, sightings: (previous?.sightings ?? 0) + 1, lastSeen: Date())
        updateAssessment()
    }

    private func sample() {
        guard isScanning else { return }
        if let rssi = WiFiReader.snapshot()?.rssi {
            wifiSamples.append(rssi)
            if wifiSamples.count > 30 { wifiSamples.removeFirst() }
        }
        let now = Date()
        signals = signals.filter { now.timeIntervalSince($0.value.lastSeen) <= 30 }
        secondsRemaining = max(0, Int(ceil(deadline?.timeIntervalSince(now) ?? 0)))
        updateAssessment()
        if secondsRemaining == 0 { stop() }
    }

    private func updateAssessment() {
        let now = Date()
        let clues = signals.values.map {
            BluetoothClue(rssi: $0.rssi, sightings: $0.sightings,
                          ageSeconds: now.timeIntervalSince($0.lastSeen))
        }
        assessment = PresenceAnalyzer.assess(bluetooth: clues, wifiSamples: wifiSamples)
    }
}

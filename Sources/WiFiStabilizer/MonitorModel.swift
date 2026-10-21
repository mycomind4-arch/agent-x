import CoreLocation
import Foundation
import StabilizerCore

struct HistoryPoint: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let profile: String
    let rssi: Int
    let latencyMS: Double?
    let packetLossPercent: Double?
}

private final class HistoryStore {
    private let url: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WiFiStabilizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("history.jsonl")
    }

    func load() -> [HistoryPoint] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        return Array(data.split(separator: 10)
            .compactMap { try? decoder.decode(HistoryPoint.self, from: Data($0)) }
            .filter { $0.date > cutoff }
            .suffix(30_000))
    }

    func append(_ point: HistoryPoint) {
        guard var data = try? JSONEncoder().encode(point) else { return }
        data.append(10)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    func compact(_ points: [HistoryPoint]) {
        let encoder = JSONEncoder()
        var data = Data()
        for point in points {
            guard let line = try? encoder.encode(point) else { continue }
            data.append(line)
            data.append(10)
        }
        try? data.write(to: url, options: .atomic)
    }
}

@MainActor
final class MonitorModel: ObservableObject {
    let presence = PresenceScanner()
    let camera = CameraPresenceScanner()
    let speech = SpeechPresenceScanner()
    @Published private(set) var link: LinkSnapshot?
    @Published private(set) var probe: ProbeSnapshot?
    @Published private(set) var nearby: [NearbyNetwork] = []
    @Published private(set) var history: [HistoryPoint] = []
    @Published private(set) var scanMessage: String?
    @Published private(set) var isScanning = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRecovery: Date?
    @Published var profileName: String {
        didSet { UserDefaults.standard.set(profileName, forKey: "profileName") }
    }
    @Published var autoRecoveryEnabled: Bool {
        didSet { UserDefaults.standard.set(autoRecoveryEnabled, forKey: "autoRecoveryEnabled") }
    }

    private let store = HistoryStore()
    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var consecutiveFailures = 0
    private var samplesSinceCompaction = 0

    init() {
        let savedName = UserDefaults.standard.string(forKey: "profileName") ?? "Home"
        profileName = savedName
        autoRecoveryEnabled = UserDefaults.standard.bool(forKey: "autoRecoveryEnabled")
        history = store.load()
        if !history.isEmpty { store.compact(history) }
    }

    var guidance: [String] { Diagnostics.guidance(link: link, probe: probe, nearby: nearby) }

    var profileHistory: [HistoryPoint] {
        history.filter { $0.profile == profileName && $0.date > Date().addingTimeInterval(-86_400) }
    }

    func start() {
        guard timer == nil else { return }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor in await monitor.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let currentLink = WiFiReader.snapshot()
        link = currentLink
        if let currentLink {
            probe = await NetworkProbe.sample(interfaceName: currentLink.interfaceName)
        } else {
            probe = nil
        }
        isRefreshing = false

        if let link {
            let point = HistoryPoint(date: Date(), profile: profileName, rssi: link.rssi,
                                     latencyMS: probe?.latencyMS, packetLossPercent: probe?.packetLossPercent)
            history.append(point)
            store.append(point)
            samplesSinceCompaction += 1
            let cutoff = Date().addingTimeInterval(-7 * 86_400)
            history = Array(history.filter { $0.date > cutoff }.suffix(30_000))
            if samplesSinceCompaction >= 1440 {
                store.compact(history)
                samplesSinceCompaction = 0
            }
        }

        if link != nil && probe?.internetReachable == false {
            consecutiveFailures += 1
        } else {
            consecutiveFailures = 0
        }
        if autoRecoveryEnabled,
           Diagnostics.shouldReconnect(link: link, probe: probe, consecutiveFailures: consecutiveFailures,
                                       lastAttempt: lastRecovery, now: Date()) {
            reconnect()
        }
    }

    func scanNearby() {
        guard !isScanning else { return }
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            scanMessage = "Allow Location Services for network names, then scan again."
            return
        }
        isScanning = true
        scanMessage = nil
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try WiFiReader.scan() }
            DispatchQueue.main.async {
                self.isScanning = false
                switch result {
                case .success(let networks):
                    self.nearby = networks
                    self.scanMessage = networks.isEmpty ? "No nearby networks were returned. macOS may need Location Services access." : nil
                case .failure(let error):
                    self.scanMessage = "Scan unavailable: \(error.localizedDescription)"
                }
            }
        }
    }

    func reconnect() {
        guard link != nil else { return }
        lastRecovery = Date()
        consecutiveFailures = 0
        WiFiReader.reconnect()
    }
}

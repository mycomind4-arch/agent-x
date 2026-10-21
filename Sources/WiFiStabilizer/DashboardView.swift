import AppKit
import Charts
import StabilizerCore
import SwiftUI

private enum Page: String, CaseIterable {
    case overview = "Overview"
    case presence = "Presence"
    case nearby = "Nearby"
    case history = "History"
    case settings = "Settings"
}

struct DashboardView: View {
    @ObservedObject var model: MonitorModel
    @State private var page: Page = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Label("Overview", systemImage: "waveform.path.ecg").tag(Page.overview)
                Label("Presence", systemImage: "person.crop.circle.dashed").tag(Page.presence)
                Label("Nearby", systemImage: "wifi.router").tag(Page.nearby)
                Label("History", systemImage: "chart.xyaxis.line").tag(Page.history)
                Label("Settings", systemImage: "gearshape").tag(Page.settings)
            }
            .navigationTitle("Wi-Fi Stabilizer")
            .frame(minWidth: 165)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .overview: overview
                    case .presence:
                        PresenceView(radio: model.presence, camera: model.camera, speech: model.speech)
                    case .nearby: nearby
                    case .history: history
                    case .settings: settings
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Connection overview", subtitle: "Live Wi-Fi and internet health for \(model.profileName)")

            HStack(spacing: 18) {
                Image(systemName: model.link == nil ? "wifi.slash" : "wifi")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(qualityColor)
                    .frame(width: 68, height: 68)
                    .background(qualityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.link.map { SignalQuality.from(rssi: $0.rssi).rawValue } ?? "No Wi-Fi connection")
                        .font(.system(size: 28, weight: .semibold))
                    Text(model.link?.networkName ?? (model.link == nil ? "Connect to Wi-Fi to begin" : "Network name hidden by macOS"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let probe = model.probe {
                    Label(probe.internetReachable ? "Internet reachable" : "Internet probe failed",
                          systemImage: probe.internetReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(probe.internetReachable ? .green : .orange)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                metric("Signal", model.link.map { "\($0.rssi) dBm" } ?? "—", detail: "Received strength", symbol: "antenna.radiowaves.left.and.right")
                metric("Noise", model.link?.noise.map { "\($0) dBm" } ?? "—", detail: "Background level", symbol: "waveform")
                metric("Signal to noise", model.link?.snr.map { "\($0) dB" } ?? "—", detail: "Higher is better", symbol: "chart.bar")
                metric("Transmit rate", model.link.map { String(format: "%.0f Mbps", $0.transmitRate) } ?? "—", detail: "Radio link rate", symbol: "arrow.up.arrow.down")
                metric("Channel", model.link?.channel.map(String.init) ?? "—", detail: model.link?.band.rawValue ?? "Wi-Fi band", symbol: "circle.grid.cross")
                metric("Latency", model.probe?.latencyMS.map { String(format: "%.0f ms", $0) } ?? "—", detail: "Internet test", symbol: "timer")
                metric("Packet loss", model.probe?.packetLossPercent.map { String(format: "%.0f%%", $0) } ?? "—", detail: "ICMP test, 3 packets", symbol: "waveform.path")
                metric("DNS", dnsStatus, detail: "example.com lookup", symbol: "network")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What to try").font(.title3.bold())
                ForEach(model.guidance, id: \.self) { advice in
                    Label(advice, systemImage: "lightbulb")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()

            if let note = model.probe?.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Text("Tests use 1.1.1.1 and example.com. Signal readings come from this Mac; software cannot increase radio power.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var nearby: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Nearby networks", subtitle: "Scan on demand to check channel crowding")
            HStack {
                Button {
                    model.scanNearby()
                } label: {
                    Label(model.isScanning ? "Scanning…" : "Scan nearby Wi-Fi", systemImage: "wifi.router")
                }
                .disabled(model.isScanning)
                if model.isScanning { ProgressView().controlSize(.small) }
            }
            Text("Scanning can briefly interrupt the connection. macOS may hide network names or require Location Services access.")
                .font(.caption).foregroundStyle(.secondary)

            if let message = model.scanMessage {
                Text(message).foregroundStyle(.secondary)
            }
            if !model.nearby.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.nearby) { network in
                        HStack {
                            Image(systemName: "wifi").foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(network.name).fontWeight(.medium)
                                Text("\(network.band.rawValue) · channel \(network.channel)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(network.rssi) dBm").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 9)
                        if network.id != model.nearby.last?.id { Divider() }
                    }
                }
                .card()
                if let link = model.link {
                    Text(String(format: "Estimated overlap on your channel: %.1f", Diagnostics.channelLoad(for: link, nearby: model.nearby)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Connection history", subtitle: "Last 24 hours for \(model.profileName)")
            if model.profileHistory.isEmpty {
                Text("History appears after the first reading.")
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .foregroundStyle(.secondary)
                    .card()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Signal strength").font(.headline)
                    Chart(model.profileHistory) { point in
                        LineMark(x: .value("Time", point.date), y: .value("RSSI", point.rssi))
                            .foregroundStyle(.blue)
                    }
                    .frame(height: 220)
                    Text("More negative dBm means a weaker signal. Data stays on this Mac and is kept for seven days.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .card()
                if model.profileHistory.contains(where: { $0.latencyMS != nil }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Internet latency").font(.headline)
                        Chart(model.profileHistory.compactMap { point -> (Date, Double)? in
                            point.latencyMS.map { (point.date, $0) }
                        }, id: \.0) { point in
                            LineMark(x: .value("Time", point.0), y: .value("Milliseconds", point.1))
                                .foregroundStyle(.orange)
                        }
                        .frame(height: 180)
                    }
                    .card()
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            header("Settings", subtitle: "Choose how the monitor responds")
            VStack(alignment: .leading, spacing: 16) {
                Text("Location profile").font(.headline)
                TextField("Profile name", text: $model.profileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                Text("Name this spot so its readings stay together in History. You can change the name when you move the Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Automatic reconnect", isOn: $model.autoRecoveryEnabled)
                    .font(.headline)
                Text("When the signal is very weak and three internet checks fail in a row, disconnect from Wi-Fi and let macOS rejoin. At most one attempt every ten minutes. This briefly interrupts traffic and macOS may not rejoin automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reconnect now") { model.reconnect() }
                    .disabled(model.link == nil)
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Text("Router and DNS").font(.headline)
                Text("Band, channel, and system DNS changes are made in your router or macOS settings. The app shows when those changes may help.")
                    .foregroundStyle(.secondary)
                Button("Open Network Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .card()
        }
    }

    private var dnsStatus: String {
        guard let probe = model.probe else { return "—" }
        if probe.dnsReachable { return "Working" }
        return probe.internetReachable ? "Problem" : "Unknown"
    }

    private var qualityColor: Color {
        guard let link = model.link else { return .gray }
        switch SignalQuality.from(rssi: link.rssi) {
        case .excellent, .good: return .green
        case .fair, .weak: return .orange
        case .veryWeak, .unusable: return .red
        }
    }

    private func header(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, _ value: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension View {
    func card() -> some View { modifier(CardModifier()) }
}

struct MenuBarView: View {
    @ObservedObject var model: MonitorModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wi-Fi Stabilizer").font(.headline)
            if let link = model.link {
                Text("\(SignalQuality.from(rssi: link.rssi).rawValue) · \(link.rssi) dBm · \(link.band.rawValue)")
                Text(model.probe?.internetReachable == true ? "Internet reachable" : "Internet test pending or failed")
                    .foregroundStyle(.secondary)
            } else {
                Text("No Wi-Fi connection").foregroundStyle(.secondary)
            }
            HStack {
                Button("Open dashboard") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }
                Button("Refresh") { Task { await model.refresh() } }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

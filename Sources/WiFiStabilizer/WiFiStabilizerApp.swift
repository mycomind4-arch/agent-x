import SwiftUI

@main
struct WiFiStabilizerApp: App {
    @StateObject private var monitor = MonitorModel()

    var body: some Scene {
        WindowGroup("Wi-Fi Stabilizer", id: "main") {
            DashboardView(model: monitor)
                .frame(minWidth: 780, minHeight: 580)
                .onAppear { monitor.start() }
        }
        .windowStyle(.titleBar)

        MenuBarExtra("Wi-Fi Stabilizer", systemImage: "wifi") {
            MenuBarView(model: monitor)
                .onAppear { monitor.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

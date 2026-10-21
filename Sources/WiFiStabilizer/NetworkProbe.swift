import Foundation
import Network
import StabilizerCore

enum NetworkProbe {
    private final class ConnectionResult: @unchecked Sendable {
        private let lock = NSLock()
        private var finished = false
        private let continuation: CheckedContinuation<(Bool, Double?), Never>
        private let connection: NWConnection
        private let start = DispatchTime.now()

        init(connection: NWConnection, continuation: CheckedContinuation<(Bool, Double?), Never>) {
            self.connection = connection
            self.continuation = continuation
        }

        func finish(_ success: Bool) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            lock.unlock()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            connection.cancel()
            continuation.resume(returning: (success, success ? elapsed : nil))
        }
    }

    static func sample(interfaceName: String) async -> ProbeSnapshot {
        async let direct = tcpConnect(host: "1.1.1.1")
        async let named = tcpConnect(host: "example.com")
        async let ping = pingCloudflare(interfaceName: interfaceName)
        let (directOK, tcpLatency) = await direct
        let (namedOK, _) = await named
        let pingResult = await ping

        let icmpUnavailable = pingResult?.lossPercent == 100 && directOK
        return ProbeSnapshot(
            internetReachable: directOK || namedOK,
            dnsReachable: namedOK,
            latencyMS: icmpUnavailable ? tcpLatency : (pingResult?.averageMS ?? tcpLatency),
            packetLossPercent: icmpUnavailable ? nil : pingResult?.lossPercent,
            note: icmpUnavailable ? "ICMP replies unavailable; latency is TCP connection time." : nil
        )
    }

    private static func tcpConnect(host: String) async -> (Bool, Double?) {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "WiFiStabilizer.tcp.\(host)")
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .wifi
            let connection = NWConnection(host: NWEndpoint.Host(host), port: 443, using: parameters)
            let result = ConnectionResult(connection: connection, continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: result.finish(true)
                case .failed, .cancelled: result.finish(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 3) { result.finish(false) }
        }
    }

    private static func pingCloudflare(interfaceName: String) async -> PingResult? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-n", "-b", interfaceName, "-c", "3", "-i", "0.3", "-W", "1000", "1.1.1.1"]
                let output = Pipe()
                process.standardOutput = output
                process.standardError = output
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: PingResult.parse(String(decoding: data, as: UTF8.self)))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

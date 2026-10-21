import StabilizerCore
import SwiftUI

struct PresenceView: View {
    @ObservedObject var radio: PresenceScanner
    @ObservedObject var camera: CameraPresenceScanner
    @ObservedObject var speech: SpeechPresenceScanner

    private var recentSpeech: Double? {
        guard let last = speech.lastSpeech, Date().timeIntervalSince(last) < 30 else { return nil }
        return speech.speechConfidence >= 0.55 ? speech.speechConfidence : 0.55
    }

    private var conclusion: CombinedPresence {
        PresenceFusion.combine(peopleInCamera: camera.peopleInView,
                               recentSpeechConfidence: recentSpeech,
                               radio: radio.assessment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Presence sensing").font(.largeTitle.bold())
                Text("Combine the Mac’s camera, microphone, Bluetooth, and Wi-Fi clues")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(conclusion.title, systemImage: conclusion.directEvidence ? "person.fill.viewfinder" : "sensor.tag.radiowaves.forward")
                    .font(.title2.bold())
                    .foregroundStyle(conclusion.directEvidence ? .green : .primary)
                Text(conclusion.explanation).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

            HStack(alignment: .top, spacing: 14) {
                sensorCard(title: "Camera", icon: "video", status: camera.status) {
                    Button(camera.isRunning ? "Stop camera" : "Start camera") {
                        camera.isRunning ? camera.stop() : camera.start()
                    }
                    if let count = camera.peopleInView {
                        Text("People in view: \(count)").fontWeight(.medium)
                    }
                }
                sensorCard(title: "Microphone", icon: "mic", status: speech.status) {
                    Button(speech.isRunning ? "Stop microphone" : "Listen for speech") {
                        speech.isRunning ? speech.stop() : speech.start()
                    }
                    if recentSpeech != nil {
                        Text("Speech-like sound heard recently").fontWeight(.medium)
                    }
                }
            }

            if camera.isRunning {
                CameraPreviewView(session: camera.session)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottomLeading) {
                        Text("Live camera view · processed on this Mac")
                            .font(.caption)
                            .padding(8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(10)
                    }
            }

            sensorCard(title: "Radio clues", icon: "waveform.path", status: radio.status) {
                Button(radio.isScanning ? "Stop radio scan" : "Scan for 60 seconds") {
                    radio.isScanning ? radio.stop() : radio.start()
                }
                if radio.isScanning { Text("\(radio.secondsRemaining) seconds left").foregroundStyle(.secondary) }
                HStack(spacing: 24) {
                    Label("\(radio.assessment.nearbySignalCount) nearby Bluetooth signals", systemImage: "dot.radiowaves.left.and.right")
                    Label(radio.assessment.wifiChanged ? "Wi-Fi changed" : "Wi-Fi steady", systemImage: "wifi")
                }
                .font(.caption)
            }

            Text("Only the camera can directly identify a person, and only within its view. Speech may come from a speaker. Bluetooth devices are not people, and Wi-Fi changes are not proof of movement. This Mac cannot form a through-wall image from its normal Wi-Fi readings.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Sensors start only when you press their buttons. Video and audio are processed on this Mac; they are not saved or uploaded. Bluetooth identifiers remain in memory only during a scan.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear {
            radio.stop()
            camera.stop()
            speech.stop()
        }
    }

    private func sensorCard<Content: View>(title: String, icon: String, status: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            Text(status).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

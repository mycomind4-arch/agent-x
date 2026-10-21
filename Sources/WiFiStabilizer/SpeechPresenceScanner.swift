import AVFoundation
import Foundation
import SoundAnalysis

final class SpeechPresenceScanner: NSObject, ObservableObject, SNResultsObserving {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Microphone is off"
    @Published private(set) var lastSpeech: Date?
    @Published private(set) var speechConfidence: Double = 0

    private var engine: AVAudioEngine?
    private var analyzer: SNAudioStreamAnalyzer?

    func start() {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: configureAndStart()
        case .notDetermined:
            status = "Waiting for microphone permission…"
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed { self?.configureAndStart() }
                    else { self?.status = "Microphone access was not allowed." }
                }
            }
        default: status = "Microphone access is unavailable. Check Privacy & Security settings."
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        analyzer?.removeAllRequests()
        analyzer = nil
        engine = nil
        isRunning = false
        status = "Microphone is off"
    }

    private func configureAndStart() {
        do {
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                status = "No microphone is available."
                return
            }
            let analyzer = SNAudioStreamAnalyzer(format: format)
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            try analyzer.add(request, withObserver: self)
            input.installTap(onBus: 0, bufferSize: 8192, format: format) { buffer, time in
                analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            engine.prepare()
            try engine.start()
            self.engine = engine
            self.analyzer = analyzer
            isRunning = true
            status = "Listening for speech sounds on this Mac"
        } catch {
            status = "Sound analysis could not start: \(error.localizedDescription)"
        }
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let confidence = result.classifications
            .filter {
                let name = $0.identifier.lowercased()
                return name.contains("speech") || name.contains("laughter") || name.contains("conversation")
            }
            .map(\.confidence)
            .max() ?? 0
        DispatchQueue.main.async {
            guard self.isRunning else { return }
            self.speechConfidence = confidence
            if confidence >= 0.55 { self.lastSpeech = Date() }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { self.status = "Sound analysis error: \(error.localizedDescription)" }
    }
}

import AVFoundation
import Foundation
import SwiftUI
import Vision

final class CameraPresenceScanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var peopleInView: Int?
    @Published private(set) var status = "Camera is off"

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "WiFiStabilizer.camera.session")
    private let frameQueue = DispatchQueue(label: "WiFiStabilizer.camera.frames")
    private var lastAnalysis = Date.distantPast

    func start() {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            status = "Waiting for camera permission…"
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed { self?.configureAndStart() }
                    else { self?.status = "Camera access was not allowed." }
                }
            }
        default: status = "Camera access is unavailable. Check Privacy & Security settings."
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.peopleInView = nil
                self?.status = "Camera is off"
            }
        }
    }

    private func configureAndStart() {
        status = "Starting camera…"
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    DispatchQueue.main.async { self.status = "No camera is available." }
                    return
                }
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.frameQueue)
                self.session.beginConfiguration()
                self.session.sessionPreset = .low
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(output) { self.session.addOutput(output) }
                self.session.commitConfiguration()
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                self.status = self.session.isRunning ? "Looking for people in camera view" : "Camera could not start."
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastAnalysis) >= 1,
              let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = Date()
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = true
        let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        do {
            try handler.perform([request])
            let count = (request.results ?? []).filter { $0.confidence >= 0.5 }.count
            DispatchQueue.main.async { self.peopleInView = count }
        } catch {
            DispatchQueue.main.async { self.status = "Camera analysis unavailable." }
        }
    }
}

final class CameraPreview: NSView {
    override func makeBackingLayer() -> CALayer { AVCaptureVideoPreviewLayer() }
    override var wantsUpdateLayer: Bool { true }

    var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreview {
        let view = CameraPreview()
        view.wantsLayer = true
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ view: CameraPreview, context: Context) {
        view.previewLayer?.session = session
    }
}

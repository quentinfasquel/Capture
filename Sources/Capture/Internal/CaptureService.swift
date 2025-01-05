//
//  CaptureService.swift
//  Capture
//
//  Created by Quentin Fasquel on 04/01/2025.
//

@preconcurrency import AVFoundation

actor CaptureService {

    private let captureSession: AVCaptureSession
    private let captureSessionExecutor: DispatchQueueExecutor
    private var captureAudioInput: AVCaptureDeviceInput?
    private var captureVideoInput: AVCaptureDeviceInput?
    private var isCapturedSessionConfigured: Bool = false

    private let movieCapture: MovieCapture = .init()
    private let photoCapture: PhotoCapture = .init()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        captureSessionExecutor.asUnownedSerialExecutor()
    }

    init(session: AVCaptureSession, queue: DispatchQueue) {
        captureSession = session
        captureSessionExecutor = DispatchQueueExecutor(queue: queue)
    }

    func configure(
        cameraDevice: AVCaptureDevice?,
        microphoneDevice: AVCaptureDevice?,
        sessionPreset: AVCaptureSession.Preset,
        previewLayer: AVCaptureVideoPreviewLayer,
        recordingSettings: RecordingSettings?
    ) throws {

        guard let cameraDevice = cameraDevice ?? .default(for: .video) else {
            log(.cameraDeviceNotSet)
            return
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        configureCaptureSessionPreset(sessionPreset)
        try configureCaptureVideoInput(cameraDevice, microphoneDevice: microphoneDevice)

        configureCaptureMovieOutput(settings: recordingSettings)
        configureCapturePhotoOutput()
        configureCapturePreviewOutput(previewLayer: previewLayer)
        configureCaptureOutputMirroring()
        // TODO: video rotation angle / video orientation

        isCapturedSessionConfigured = true
    }

    func startCaptureSession() {
        guard isCapturedSessionConfigured else {
            return
        }
        captureSession.startRunning()
    }

    func stopCaptureSession() {
        captureSession.stopRunning()
    }

    func startRecording() {
        movieCapture.startRecording()
    }

    func stopRecording() async throws -> URL {
        try await movieCapture.stopRecording()
    }

    func capturePhoto() async throws -> AVCapturePhoto {
        try await photoCapture.capturePhoto()
    }

    func setCaptureDevice(_ captureDevice: AVCaptureDevice) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let captureVideoInput {
            captureSession.removeInput(captureVideoInput)
        }

        try configureCaptureVideoInput(captureDevice, microphoneDevice: captureAudioInput?.device)
        configureCaptureOutputMirroring()
    }

    private var videoConnections: [AVCaptureConnection] {
        captureSession.outputs.compactMap { $0.connection(with: .video) }
    }

    private func configureCaptureSessionPreset(_ sessionPreset: AVCaptureSession.Preset) {
        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        } else {
             log(.cannotSetSessionPreset)
        }
    }

    private func configureCaptureVideoInput(
        _ cameraDevice: AVCaptureDevice,
        microphoneDevice: AVCaptureDevice?
    ) throws {
        let videoInput = try AVCaptureDeviceInput(device: cameraDevice)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            captureVideoInput = videoInput
        } else {
             log(.cannotAddVideoInput)
        }

        if let microphoneDevice {
            let audioInput = try AVCaptureDeviceInput(device: microphoneDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                captureAudioInput = audioInput
            } else {
                log(.cannotAddAudioInput)
            }
        }
    }

    private func configureCapturePhotoOutput() {
        let photoOutput = photoCapture.capturePhotoOutput
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
             log(.cannotAddPhotoOutput)
        }
    }

    internal func configureCaptureMovieOutput(settings: RecordingSettings?) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        let previousMovieOutput = movieCapture.movieOutput
        if let movieOutput = movieCapture.configureOutput(settings: settings) {
            if let previousMovieOutput {
                captureSession.removeOutput(previousMovieOutput)
            }

            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
            } else {
                log(.cannotAddVideoFileOutput)
            }
        }
    }

    private func configureCapturePreviewOutput(previewLayer: AVCaptureVideoPreviewLayer) {
        previewLayer.session = captureSession
    }

    private func configureCaptureOutputMirroring() {
        guard let captureDevice = captureVideoInput?.device else {
            return
        }

        let isVideoMirrored = captureDevice.position == .front
        videoConnections.forEach { connection in
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
        }
    }

    func updateCaptureOutputOrientation(_ videoOrientation: AVCaptureVideoOrientation) {
        videoConnections.forEach { connection in
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
}

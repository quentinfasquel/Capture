//
//  Camera.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

@preconcurrency import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit.UIDevice
#endif

public enum CameraError: Error {
    case missingPhotoOutput
    case missingVideoOutput
}

@MainActor
public final class Camera: NSObject, ObservableObject {

    public static let `default` = Camera(.back)

    private let sessionQueue = DispatchQueue(label: "\(bundleIdentifier).Camera.Session")
    private let sessionPreset: AVCaptureSession.Preset

    private var isCaptureSessionConfigured = false

    private let deviceLookup = CaptureDeviceLookup()
    private let movieCapture = MovieCapture()
    private let photoCapture = PhotoCapture()

    // MARK: - Internal Properties

    let captureSession = AVCaptureSession()
    var devicePosition: CameraPosition
    var recordingSettings: RecordingSettings?
    var isAudioEnabled: Bool

    // MARK: - Public API

    public private(set) var previewLayer: AVCaptureVideoPreviewLayer

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isPreviewPaused: Bool = false
    @Published public private(set) var devices: [AVCaptureDevice] = []
    @Published public var captureDevice: AVCaptureDevice? {
        didSet {
            if oldValue != captureDevice, let captureDevice {
                captureDeviceDidChange(captureDevice)
            }
        }
    }

    ///
    /// Instantiate a Camera instance with a high capture session preset
    /// - parameter position: the initial AVCaptureDevice.Position to use
    /// - parameter audioEnabled: whether audio should be enabled when recording videos. The default value is `true`.
    /// Typically set this value to `false` when using the Camera to only take pictures, avoiding to requesting audio permissions.
    ///
    public convenience init(
        _ position: CameraPosition,
        audioEnabled: Bool = true
    ) {
        self.init(
            position: position,
            preset: .high,
            audioEnabled: audioEnabled
        )
    }

    ///
    /// Instantiate a Camera instance
    /// - parameter position: the initial AVCaptureDevice.Position to use
    /// - parameter preset: the capture session's preset to use
    /// - parameter audioEnabled: whether audio should be enabled when recording videos. The default value is `true`.
    /// Typically set this value to `false` when using the Camera to only take pictures, avoiding to requesting audio permissions.
    ///
    public required init(
        position: CameraPosition,
        preset: AVCaptureSession.Preset,
        audioEnabled: Bool = true
    ) {
        devicePosition = position
        sessionPreset = preset
        isAudioEnabled = audioEnabled
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init()
        #if os(iOS)
        Task { @MainActor in
            registerDeviceOrientationObserver()
        }
        #endif
        devices = deviceLookup.availableCaptureDevices
    }
    
    deinit {
        #if os(iOS)
        Task { @MainActor in
            // Stop observing device orientation
            Self.stopObservingDeviceOrientation()
        }
        #endif
        print(#function, self)
    }

    public func start() async {
        guard await checkAuthorization() else {
            logger.error("Camera access was not authorized.")
            return
        }

        guard !captureSession.isRunning else {
            logger.info("Camera is already running")
            return
        }

        if isCaptureSessionConfigured {
            return startCaptureSession()
        }

        sessionQueue.async { [self] in
            guard configureCaptureSession() else {
                return
            }

            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    public func stop() {
        guard isCaptureSessionConfigured else {
            return
        }

        stopCaptureSession()
    }

    @MainActor
    public func pause() {
        isPreviewPaused = true
    }

    @MainActor
    public func resume() {
        isPreviewPaused = false
        Task { await start() }
    }

    public func setCaptureDevice(_ device: AVCaptureDevice) {
        captureDevice = device
    }
    
    public func switchCaptureDevice() {
        switch captureDevice?.position {
        case .back:
            updateCaptureDevice(forDevicePosition: .front)
        case .front:
            updateCaptureDevice(forDevicePosition: .back)
        default:
            break
        }
    }
    
    // MARK: Capture Action

    internal func updateRecordingSettings(_ newRecordingSettings: RecordingSettings?) {
        guard recordingSettings != newRecordingSettings else {
            return
        }

        recordingSettings = newRecordingSettings

        guard isCaptureSessionConfigured else {
            // else it will be applied during session configuration
            return
        }

        sessionQueue.async { [self] in
            updateCaptureVideoOutput(newRecordingSettings)
        }
    }

    public func startRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        sessionQueue.async { [self] in
            movieCapture.startRecording()
        }
    }

    public func stopRecording() async throws -> URL {
        defer { isRecording = false }
        // sessionQueue.async
        return try await movieCapture.stopRecording()
    }

    public func takePicture() async throws -> AVCapturePhoto {
        // sessionQueue.async
        try await photoCapture.capturePhoto()
    }

    // MARK: - Capture Device Management

    private func updateCaptureDevice(forDevicePosition devicePosition: AVCaptureDevice.Position) {
        if case .unspecified = devicePosition {
            captureDevice = AVCaptureDevice.default(for: .video)
        } else if let device = deviceLookup.captureDevices.first(where: { $0.position == devicePosition }) {
            captureDevice = device
        } else {
            logger.warning("Couldn't update capture device for \(String(describing: devicePosition))")
        }
    }

    // MARK: - Authorization Handling

    public var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    @discardableResult
    func checkAuthorization() async -> Bool {
        switch authorizationStatus {
            case .authorized:
                return true
            case .notDetermined:
                logger.debug("Camera access not determined.")
                sessionQueue.suspend()
                let status = await AVCaptureDevice.requestAccess(for: .video)
                sessionQueue.resume()
                if status {
                    logger.debug("Camera access authorized.")
                }
                return status
            case .denied:
                logger.debug("Camera access denied.")
                return false
            case .restricted:
                logger.debug("Camera library access restricted.")
                return false
            @unknown default:
                return false
        }
    }

    // MARK: - Capture Session Configuration

    private var videoConnections: [AVCaptureConnection] {
        captureSession.outputs.compactMap { $0.connection(with: .video) }
    }

    private func configureCaptureSession() -> Bool {
        guard case .authorized = authorizationStatus else {
            return false
        }

        updateCaptureDevice(forDevicePosition: devicePosition)

        guard let captureDevice else {
            log(.cameraDeviceNotSet)
            return false
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        } else {
            captureSession.sessionPreset = .high
            log(.cannotSetSessionPreset)
        }

        // Adding video input (used for both photo and video capture)
        let videoInput = AVCaptureDeviceInput(device: captureDevice, logger: logger)
        if let videoInput, captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            captureVideoInput = videoInput
        } else {
            log(.cannotAddVideoInput)
        }

        // Configure photo capture
        let photoOutput = photoCapture.capturePhotoOutput
        photoOutput.maxPhotoQualityPrioritization = .quality
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            log(.cannotAddPhotoOutput)
        }

        // Configure video capture
        if isAudioEnabled {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = AVCaptureDeviceInput(device: audioDevice, logger: logger)
            if let audioInput, captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            } else {
                log(.cannotAddAudioInput)
            }
        }

        updateCaptureVideoOutput(recordingSettings)

        isCaptureSessionConfigured = true
        return true
    }
    
    private func updateCaptureVideoInput(_ cameraDevice: AVCaptureDevice) {
        guard case .authorized = authorizationStatus else {
            return
        }

        guard isCaptureSessionConfigured else {
            if configureCaptureSession(), !isPreviewPaused {
                startCaptureSession()
            }
            return
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove current camera input
        if let videoInput = captureVideoInput {
            captureSession.removeInput(videoInput)
            captureVideoInput = nil
        }

        // Add new camera input
        let videoInput = AVCaptureDeviceInput(device: cameraDevice, logger: logger)
        if let videoInput, captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            captureVideoInput = videoInput
        }

        updateCaptureOutputMirroring()
        updateCaptureOutputOrientation()
    }

    private func updateCaptureVideoOutput(_ recordingSettings: RecordingSettings?) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        let previousMovieOutput = movieCapture.movieOutput
        if let movieOutput = movieCapture.configureOutput(settings: recordingSettings) {
            if let previousMovieOutput {
                captureSession.removeOutput(previousMovieOutput)
            }

            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
            } else {
                log(.cannotAddVideoFileOutput)
            }
        }

        updateCaptureOutputMirroring()
        updateCaptureOutputOrientation()
    }

    private func updateCaptureOutputMirroring() {
        guard let captureDevice else {
            return
        }

        let isVideoMirrored = captureDevice.position == .front
        videoConnections.forEach { videoConnection in
            if videoConnection.isVideoMirroringSupported {
                videoConnection.isVideoMirrored = isVideoMirrored
            }
        }
    }

    private func updateCaptureOutputOrientation() {
#if os(iOS)
        var deviceOrientation = UIDevice.current.orientation
        logger.debug("Updating capture outputs video orientation: \(String(describing: deviceOrientation))")
        if case .unknown = deviceOrientation {
            // Fix device orientation using's screen coordinate space
            deviceOrientation = UIScreen.main.deviceOrientation
        }

        videoConnections.forEach { videoConnection in
            if videoConnection.isVideoOrientationSupported {
                videoConnection.videoOrientation = AVCaptureVideoOrientation(deviceOrientation)
            }
        }
#elseif os(macOS)
#endif
    }

    private func startCaptureSession() {
#if os(iOS)
        Task { @MainActor in
            Self.startObservingDeviceOrientation()
        }
#endif
        if !captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    private func stopCaptureSession() {
#if os(iOS)
        Task { @MainActor in
            Self.stopObservingDeviceOrientation()
        }
#endif
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }

    // MARK: -

    public var isVideoMirrored: Bool {
        videoConnections.first?.isVideoMirrored ?? false
    }

    // MARK: - Device Orientation Handling
#if os(iOS)
    private var deviceOrientationObserver: NSObjectProtocol?

    @MainActor private func registerDeviceOrientationObserver() {
        deviceOrientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: UIDevice.current,
            queue: .main
        ) { [weak self] notification in
            self?.updateCaptureOutputOrientation()
        }
    }

    @MainActor private static func startObservingDeviceOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    @MainActor private static func stopObservingDeviceOrientation() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
#endif

    // MARK: - Private Methods

    private func captureDeviceDidChange(_ newCaptureDevice: AVCaptureDevice) {
        logger.debug("Using capture device: \(newCaptureDevice.localizedName)")
        sessionQueue.async { [self] in
            updateCaptureVideoInput(newCaptureDevice)
        }
    }
}

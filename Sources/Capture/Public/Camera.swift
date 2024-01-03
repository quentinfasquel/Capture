//
//  Camera.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

@_exported import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit.UIDevice
#endif

public enum CameraError: Error {
    case missingPhotoOutput
    case missingVideoOutput
}

public final class Camera: NSObject, ObservableObject {

    public static let `default` = Camera(.back)

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "\(bundleIdentifier).Camera.Session")
    private let sessionPreset: AVCaptureSession.Preset

    private var isCaptureSessionConfigured = false
    public private(set) var captureDevice: AVCaptureDevice? {
        didSet {
            if captureDevice != oldValue, let captureDevice {
                deviceId = captureDevice.uniqueID
                captureDeviceDidChange(captureDevice)
            }
        }
    }

    private var captureMovieFileOutput: AVCaptureMovieFileOutput?
    private var capturePhotoOutput: AVCapturePhotoOutput?
    private var captureVideoInput: AVCaptureDeviceInput?
    private var captureVideoFileOutput: AVCaptureVideoFileOutput?

    private var didStopRecording: ((Result<URL, Error>) -> Void)?
    private var didTakePicture: ((Result<AVCapturePhoto, Error>) -> Void)?

    // MARK: - Internal Properties
    
    var devicePosition: CameraPosition = .unspecified {
        didSet {
            if devicePosition != oldValue {
                devicePositionDidChange(devicePosition)
            }
        }
    }

    var recordingSettings: RecordingSettings?

    // MARK: - Public API
    
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isPreviewPaused: Bool = false
    @Published public private(set) var devices: [AVCaptureDevice] = []
    @Published public var deviceId: String = "" {
        didSet {
            if deviceId != captureDevice?.uniqueID {
                captureDevice = devices.first(where: { $0.uniqueID == deviceId })
            }
        }
    }
    
    public convenience init(_ position: CameraPosition) {
        self.init(position, preset: .high)
    }

    public required init(_ position: CameraPosition, preset: AVCaptureSession.Preset) {
        sessionPreset = preset
        super.init()

        devicePosition = position
        devicePositionDidChange(position)
        #if os(iOS)
        registerDeviceOrientationObserver()
        #endif
        devices = availableCaptureDevices
    }
    
    deinit {
        #if os(iOS)
        // Stop observing device orientation
        stopObservingDeviceOrientation()
        #endif
        print(#function, self)
    }
    
    public func start() async {
        guard await checkAuthorization() else {
            logger.error("Camera access was not authorized.")
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
//        startCaptureSession()
    }

    
    public func setCaptureDevice(_ device: AVCaptureDevice) {
        captureDevice = device
    }
    
    public func switchCaptureDevice() {
        let captureDevices = availableCaptureDevices
        if let captureDevice, let index = captureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % captureDevices.count
            self.captureDevice = captureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }
    
    // MARK: Capture Action

    internal func updateRecordingSettings(_ recordingSettings: RecordingSettings?) {
        self.recordingSettings = recordingSettings
        guard isCaptureSessionConfigured else {
            // else it will be applied during session configuration
            return
        }
        sessionQueue.async { [self] in
            updateCaptureVideoOutput(recordingSettings)
        }
    }

    public func startRecording() {
        guard !isRecording else {
            return
        }

        sessionQueue.async { [self] in
            let temporaryDirectory = FileManager.default.temporaryDirectory

            if let videoOutput = captureVideoFileOutput {
                let outputURL = temporaryDirectory.appending(component: "\(Date.now).mp4")
                videoOutput.startRecording(to: outputURL, recordingDelegate: self)
            } else if let videoOutput = captureMovieFileOutput {
                let outputURL = temporaryDirectory.appending(component: "\(Date.now).mov")
                videoOutput.startRecording(to: outputURL, recordingDelegate: self)
            }
        }
    }

    public func stopRecording() async throws -> URL {
        guard let videoOutput: CaptureRecording = captureVideoFileOutput ?? captureMovieFileOutput else {
            throw CameraError.missingVideoOutput
        }

        defer { didStopRecording = nil }

        return try await withCheckedThrowingContinuation { continuation in
            didStopRecording = { continuation.resume(with: $0) }
            sessionQueue.async {
                videoOutput.stopRecording()
            }
        }
    }
    
    public func takePicture() async throws -> AVCapturePhoto {
        guard let photoOutput = capturePhotoOutput else {
            throw CameraError.missingPhotoOutput
        }

        defer { didTakePicture = nil }

        
        return try await withCheckedThrowingContinuation { continuation in
            didTakePicture = { continuation.resume(with: $0) }
            sessionQueue.async {
                let photoSettings = photoOutput.photoSettings()
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
    }

    // MARK: - Capture Device Management

    private lazy var discoverySession: AVCaptureDevice.DiscoverySession = {
#if os(iOS)
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInLiDARDepthCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInTrueDepthCamera,
            .builtInWideAngleCamera,
        ]
        if #available(iOS 17, *) {
            deviceTypes.append(.continuityCamera)
        }
#elseif os(macOS)
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .deskViewCamera,
        ]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.continuityCamera)
            deviceTypes.append(.external)
        }
#endif
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
    }()

    private var backCaptureDevices: [AVCaptureDevice] {
        discoverySession.devices.filter { $0.position == .back }
    }

    private var frontCaptureDevices: [AVCaptureDevice] {
        discoverySession.devices.filter { $0.position == .front }
    }
    
    private var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += discoverySession.devices
#else
        if let defaultDevice = AVCaptureDevice.default(for: .video) {
            devices.append(defaultDevice)
        }

        if let backDevice = backCaptureDevices.first {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
#endif
        return devices
    }
    
    private var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices.filter { $0.isConnected && !$0.isSuspended }.unique()
    }

    private var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }
    
    private var isUsingBackCaptureDevice: Bool {
        guard let captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }
    
    private func updateCaptureDevice(forDevicePosition devicePosition: AVCaptureDevice.Position) {
        if case .front = devicePosition, let frontCaptureDevice = frontCaptureDevices.first {
            captureDevice = frontCaptureDevice
        } else if case .back = devicePosition, let backCaptureDevice = backCaptureDevices.first {
            captureDevice = backCaptureDevice
        } else if case .unspecified = devicePosition {
            captureDevice = AVCaptureDevice.default(for: .video)
        } else {
            logger.warning("Couldn't update capture device for \(String(describing: devicePosition))")
        }
    }

    // MARK: - Authorization Handling

    @discardableResult
    func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // logger.debug("Camera access authorized.")
            return true
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
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
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.maxPhotoQualityPrioritization = .quality
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            capturePhotoOutput = photoOutput
        } else {
            log(.cannotAddPhotoOutput)
        }

        // Configure video capture
        let audioDevice = AVCaptureDevice.default(for: .audio)
        let audioInput = AVCaptureDeviceInput(device: audioDevice, logger: logger)
        if let audioInput, captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        } else {
            log(.cannotAddAudioInput)
        }
        
        updateCaptureVideoOutput(recordingSettings)

        isCaptureSessionConfigured = true
        return true
    }
    
    private func updateCaptureVideoInput(_ cameraDevice: AVCaptureDevice) {
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
        #if os(iOS)
        updateCaptureOutputOrientation()
        #endif
    }

    private func updateCaptureVideoOutput(_ recordingSettings: RecordingSettings?) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let recordingSettings, let captureVideoFileOutput {
            captureVideoFileOutput.configureOutput(
                audioSettings: recordingSettings.audio,
                videoSettings: recordingSettings.video
            )
        } else if let recordingSettings {
            if let movieFileOutput = captureMovieFileOutput {
                captureSession.removeOutput(movieFileOutput)
                captureMovieFileOutput = nil
            }

            let videoFileOutput = AVCaptureVideoFileOutput()
            videoFileOutput.configureOutput(
                audioSettings: recordingSettings.audio,
                videoSettings: recordingSettings.video
            )
            if captureSession.canAddOutput(videoFileOutput) {
                captureSession.addOutput(videoFileOutput)
                captureVideoFileOutput = videoFileOutput
            } else {
                log(.cannotAddVideoFileOutput)
            }

        } else if captureMovieFileOutput == nil {
            if let videoFileOutput = captureVideoFileOutput {
                captureSession.removeOutput(videoFileOutput)
                captureVideoFileOutput = nil
            }

            let moveFileOutput = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(moveFileOutput) {
                captureSession.addOutput(moveFileOutput)
                captureMovieFileOutput = moveFileOutput
            } else {
                log(.cannotAddVideoFileOutput)
            }
        }

        updateCaptureOutputMirroring()
        #if os(iOS)
        updateCaptureOutputOrientation()
        #endif
    }

    private func updateCaptureOutputMirroring() {
        let isVideoMirrored = isUsingFrontCaptureDevice
        videoConnections.forEach { videoConnection in
            if videoConnection.isVideoMirroringSupported {
                videoConnection.isVideoMirrored = isVideoMirrored
            }
        }
    }

#if os(iOS)
    private func updateCaptureOutputOrientation() {
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
    }
#endif

    private func startCaptureSession() {
#if os(iOS)
        startObservingDeviceOrientation()
#endif
        if !captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    private func stopCaptureSession() {
#if os(iOS)
        stopObservingDeviceOrientation()
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

    private func registerDeviceOrientationObserver() {
        deviceOrientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: UIDevice.current,
            queue: .main
        ) { [weak self] notification in
            self?.updateCaptureOutputOrientation()
        }
    }

    private func startObservingDeviceOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    private func stopObservingDeviceOrientation() {
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
    
    private func devicePositionDidChange(_ newDevicePosition: AVCaptureDevice.Position) {
        logger.debug("Using device position: \(String(describing: newDevicePosition))")
        sessionQueue.async { [self] in
            updateCaptureDevice(forDevicePosition: newDevicePosition)
        }
    }
}

// MARK: - File Output Recording Delegate

extension Camera: AVCaptureFileOutputRecordingDelegate {

    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        isRecording = true
    }
    
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        if let error {
            didStopRecording?(.failure(error))
        } else {
            didStopRecording?(.success(outputFileURL))
        }
    }
}

// MARK: - Video File Output Recording Delegate

extension Camera: AVCaptureVideoFileOutputRecordingDelegate {

    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        isRecording = true
    }
    
    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        if let error {
            didStopRecording?(.failure(error))
        } else {
            didStopRecording?(.success(outputFileURL))
        }
    }
}

// MARK: - Photo Capture Delegate

extension Camera: AVCapturePhotoCaptureDelegate {

    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            didTakePicture?(.failure(error))
        } else {
            didTakePicture?(.success(photo))
        }
    }
}

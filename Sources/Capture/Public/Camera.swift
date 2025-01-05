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
public final class Camera: ObservableObject {

    public static let `default` = Camera(.back)

    private let captureService: CaptureService
    private let deviceLookup = CaptureDeviceLookup()
    private let sessionQueue = DispatchQueue(label: "\(bundleIdentifier).Camera.Session")

    // MARK: - Internal Properties

    var devicePosition: CameraPosition
    var sessionPreset: AVCaptureSession.Preset
    var recordingSettings: RecordingSettings?
    var isAudioEnabled: Bool

    // MARK: - Public API

    public let previewLayer = AVCaptureVideoPreviewLayer()

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
        captureService = CaptureService(session: AVCaptureSession(), queue: sessionQueue)
        devicePosition = position
        sessionPreset = preset
        isAudioEnabled = audioEnabled
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

        guard await configureCaptureService() else {
            // logger.info("Camera is already running") ?
            return
        }

        await captureService.startCaptureSession()
        Self.startObservingDeviceOrientation()
    }

    public func stop() {
        Task {
            Self.stopObservingDeviceOrientation()
            await captureService.stopCaptureSession()
        }
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
        Task { await captureService.configureCaptureMovieOutput(settings: newRecordingSettings) }

    }

    public func startRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        Task { await captureService.startRecording() }
    }

    public func stopRecording() async throws -> URL {
        defer { isRecording = false }
        return try await captureService.stopRecording()
    }

    public func takePicture() async throws -> AVCapturePhoto {
        return try await captureService.capturePhoto()
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

    private func configureCaptureService() async -> Bool {
        guard case .authorized = authorizationStatus else {
            return false
        }

        do {
            try await captureService.configure(
                cameraDevice: deviceLookup.captureDevices.first,
                microphoneDevice: isAudioEnabled ? .default(for: .audio) : nil,
                sessionPreset: sessionPreset,
                previewLayer: previewLayer,
                recordingSettings: recordingSettings
            )
            return true
        } catch {
            return false
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

        Task {
            let videoOrientation = AVCaptureVideoOrientation(deviceOrientation)
            await captureService.updateCaptureOutputOrientation(videoOrientation)
        }
#elseif os(macOS)
#endif
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
        Task {
            do {
                try await captureService.setCaptureDevice(newCaptureDevice)
                logger.debug("Using capture device: \(newCaptureDevice.localizedName)")
            } catch {
                logger.error("Error updating capture device: \(error)")
            }
        }
    }
}

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

public final class Camera: ObservableObject, @unchecked Sendable {

    public static let `default` = Camera(.back)

    private let captureService: CaptureService
    private let deviceLookup = CaptureDeviceLookup()
    private let sessionQueue = DispatchQueue(label: "\(bundleIdentifier).Camera.Session")

    // MARK: - Internal Properties

    var sessionPreset: AVCaptureSession.Preset
    var recordingSettings: RecordingSettings?
    var isAudioEnabled: Bool
    let isUserPreferredCamera: Bool

    // MARK: - Public API

    public let previewLayer = AVCaptureVideoPreviewLayer()

    @Published public private(set) var devicePosition: CameraPosition
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isPreviewPaused: Bool = false
    @Published public private(set) var devices: [AVCaptureDevice] = []
    @Published public var captureDevice: AVCaptureDevice? {
        didSet {
            devicePosition = captureDevice?.position ?? .unspecified
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
            audioEnabled: audioEnabled,
            userPreferredCamera: false
        )
    }

    ///
    /// Instantiate a Camera instance
    /// - parameter position: the initial AVCaptureDevice.Position to use
    /// - parameter preset: the capture session's preset to use
    /// - parameter audioEnabled: whether audio should be enabled when recording videos. The default value is `true`.
    /// Typically set this value to `false` when using the Camera to only take pictures, avoiding to requesting audio permissions.
    ///
    public convenience init(
        position: CameraPosition = .unspecified,
        preset: AVCaptureSession.Preset,
        audioEnabled: Bool = true
    ) {
        self.init(
            position: position,
            preset: preset,
            audioEnabled: audioEnabled,
            userPreferredCamera: false
        )
    }

    @available(iOS 17.0, *)
    public static var userPreferredCamera: Camera {
        return .userPreferredCamera(preset: .high, audioEnabled: true)
    }

    ///
    /// Instantiate a Camera instance that will match the user preferred camera and update it when switching capture device
    /// - parameter preset: the capture session's preset to use
    /// - parameter audioEnabled: whether audio should be enabled when recording videos. The default value is `true`.
    /// Typically set this value to `false` when using the Camera to only take pictures, avoiding to requesting audio permissions.
    ///
    @available(iOS 17.0, *)
    public class func userPreferredCamera(
        preset: AVCaptureSession.Preset,
        audioEnabled: Bool = true
    ) -> Camera {
        return Camera(
            position: .unspecified,
            preset: preset,
            audioEnabled: audioEnabled,
            userPreferredCamera: true
        )
    }

    private init(
        position: CameraPosition,
        preset: AVCaptureSession.Preset = .high,
        audioEnabled: Bool = true,
        userPreferredCamera: Bool = false
    ) {
        captureService = CaptureService(session: AVCaptureSession(), queue: sessionQueue)
        devicePosition = position
        sessionPreset = preset
        isAudioEnabled = audioEnabled
        isUserPreferredCamera = userPreferredCamera
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
        await Self.startObservingDeviceOrientation()
    }

    public func stop() {
        Task {
            await Self.stopObservingDeviceOrientation()
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

    @MainActor
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

    @MainActor
    public func startRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        Task { await captureService.startRecording() }
    }

    @MainActor
    public func stopRecording() async throws -> URL {
        defer { isRecording = false }
        return try await captureService.stopRecording()
    }

    @MainActor
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

    // MARK: - Capture Service Configuration

    private func configureCaptureService() async -> Bool {
        guard case .authorized = authorizationStatus else {
            return false
        }

        guard let cameraDevice = deviceLookup.camera(
            devicePosition: devicePosition,
            defaultsToUserPreferredCamera: isUserPreferredCamera
        ) else {
            return false
        }

        do {
            await MainActor.run {
                captureDevice = cameraDevice
            }

            try await captureService.configure(
                cameraDevice: cameraDevice,
                microphoneDevice: isAudioEnabled ? deviceLookup.microphone() : nil,
                sessionPreset: sessionPreset,
                previewLayer: previewLayer,
                recordingSettings: recordingSettings
            )
            return true
        } catch {
            return false
        }
    }

    private func updateCaptureOutputOrientation() async {
#if os(iOS)
        var deviceOrientation = await UIDevice.current.orientation
        logger.debug("Updating capture outputs video orientation: \(String(describing: deviceOrientation))")
        if case .unknown = deviceOrientation {
            // Fix device orientation using's screen coordinate space
            deviceOrientation = await UIScreen.main.deviceOrientation
        }

        let videoOrientation = AVCaptureVideoOrientation(deviceOrientation)
        await captureService.updateCaptureOutputOrientation(videoOrientation)
#elseif os(macOS)
#endif
    }

    // MARK: - Device Orientation Handling
#if os(iOS)
    private var deviceOrientationObserver: NSObjectProtocol?

    @MainActor
    private func registerDeviceOrientationObserver() {
        deviceOrientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: UIDevice.current,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.updateCaptureOutputOrientation()
            }
        }
    }

    @MainActor
    private static func startObservingDeviceOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    @MainActor
    private static func stopObservingDeviceOrientation() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
#endif

    // MARK: - Private Methods

    private func captureDeviceDidChange(_ newCaptureDevice: AVCaptureDevice) {
        Task {
            do {
                logger.debug("Setting capture device: \(newCaptureDevice.localizedName)")
                try await captureService.setCaptureDevice(
                    newCaptureDevice,
                    updateUserPreferredCamera: isUserPreferredCamera
                )
            } catch {
                logger.error("Error updating capture device: \(error)")
            }
        }
    }
}

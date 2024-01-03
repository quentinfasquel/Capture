//
//  CameraView.swift
//  Capture
//
//  Created by Quentin Fasquel on 07/11/2023.
//

import SwiftUI
import AVKit

public struct CameraViewOptions {
    public private(set) static var `default` = CameraViewOptions()
    var automaticallyRequestAuthorization: Bool = true
    var isTakePictureFeedbackEnabled: Bool = true
}

public struct CameraView<CameraOverlay: View>: View {

    @Binding var outputImage: PlatformImage?
    @Binding var outputVideo: URL?
    var options: CameraViewOptions
    var cameraOverlay: ((AVAuthorizationStatus) -> CameraOverlay)

    @Environment(\.recordingSettings) private var recordingSettings
    @StateObject private var camera: Camera

    @State private var authorizationStatus: AVAuthorizationStatus
    @State private var outputSize: CGSize = .zero
    @State private var showsTakePictureFeedback: Bool = false

    public init(
        camera: Camera = .default,
        outputImage: Binding<PlatformImage?> = .constant(nil),
        outputVideo: Binding<URL?> = .constant(nil),
        options: CameraViewOptions = .default,
        @ViewBuilder overlay: @escaping ((AVAuthorizationStatus) -> CameraOverlay)
    ) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        _authorizationStatus = State(initialValue: authorizationStatus)
        _camera = StateObject(wrappedValue: camera)
        _outputImage = outputImage
        _outputVideo = outputVideo
        self.options = options
        self.cameraOverlay = overlay
    }

    public var body: some View {
        ZStack {
            if case .authorized = authorizationStatus {
                CaptureVideoPreview(
                    captureSession: camera.captureSession,
                    isPaused: camera.isPreviewPaused
                )
                .blur(radius: camera.isPreviewPaused ? 20 : 0, opaque: true)
                .animation(.spring, value: camera.isPreviewPaused)
                .getSize($outputSize)
                .ignoresSafeArea()
            }

            if showsTakePictureFeedback {
                takePictureFeedback()
            }

            cameraOverlay(authorizationStatus)
        }
        .environmentObject(camera)
        .environment(\.takePicture, TakePictureAction() {
            if options.isTakePictureFeedbackEnabled {
                showsTakePictureFeedback = true
            }
            
            outputImage = await camera.takePicture(outputSize: outputSize)
        })
        .environment(\.recordVideo, RecordVideoAction(start: camera.startRecording) {
            outputVideo = await camera.stopRecording()
        })
        .onChange(of: recordingSettings) { recordingSettings in
            camera.updateRecordingSettings(recordingSettings)
        }
        .onAppear {
            camera.updateRecordingSettings(recordingSettings)
            camera.resume()
        }
        .onDisappear {
            camera.stop()
        }
        .task {
            if options.automaticallyRequestAuthorization {
                await requestAuthorizationThenStart()
            }
        }
    }

    // MARK: - Authorization Handling

    @MainActor func requestAuthorizationThenStart() async {
#if targetEnvironment(simulator)
        authorizationStatus = .denied
#else
        await camera.start()
        // Update auhtorization status
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
#endif
    }
    
    // MARK: - Subviews

    private func takePictureFeedback() -> some View {
        Color.black.ignoresSafeArea().task {
            try? await Task.sleep(for: .milliseconds(100))
            showsTakePictureFeedback = false
        }
    }
}

//
//  ContentView.swift
//  CaptureExample
//
//  Created by Quentin Fasquel on 07/12/2023.
//

import _AVKit_SwiftUI
import SwiftUI
import Capture

enum Tab: Hashable {
    case photo, video
}

struct ContentView: View {
    @State private var capturedImage: UIImage?
    @State private var recordedVideo: URL?
    @State private var path = NavigationPath()
    @State private var isPaused: Bool = false

    @StateObject private var camera: Camera = .default
    @State private var tab: Tab = .photo
    @Environment(\.takePicture) var takePicture
    
    var body: some View {
        NavigationStack(path: $path) {
            CameraView(
                camera: camera,
                outputImage: $capturedImage,
                outputVideo: $recordedVideo
            ) { authorizationStatus in
                // Environment values available:
                // - recordVideo: RecordVideoAction (startRecording / stopRecording()
                // - takePicture: TakePicutreAction (callAsFunction)
                cameraOverlay(authorizationStatus, tab: tab)
            }
            // Environment values override:
            // - recordingAudioSettings
            // - recordingVideoSettings
            .environment(\.recordingVideoSettings, VideoSettings(
                codec: .h264,
                width: 200,
                height: 200,
                scalingMode: .resizeAspectFill
            ))
            .overlay(alignment: .topTrailing) {
                cameraDevicePicker
            }
            .safeAreaInset(edge: .bottom) {
                photoVideoPicker
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $capturedImage) { image in
            Image(uiImage: image)
                .scaledToFit()
                .ignoresSafeArea()
        }
        //
        .sheet(item: $recordedVideo) { videoURL in
            VideoPlayer(player: AVPlayer(url: videoURL))
                .ignoresSafeArea()
        }
        .tint(.white)
    }
    
    @ViewBuilder var photoVideoPicker: some View {
        Picker(selection: $tab) {
            Image(systemName: "camera.fill")
                .tag(Tab.photo)
                .padding(.horizontal, 16)
            Image(systemName: "video.fill")
                .tag(Tab.video)
                .padding(.horizontal, 16)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .padding(32)
    }

    @ViewBuilder var cameraDevicePicker: some View {
        Picker(selection: $camera.deviceId) {
            ForEach(camera.devices, id: \.uniqueID) { device in
                Text(device.localizedName)
                    .tag(device.uniqueID)
            }
        } label: { EmptyView() }
    }

    
    @ViewBuilder
    func cameraOverlay(_ status: AVAuthorizationStatus, tab: Tab) -> some View {

        @Environment(\.takePicture) var takePicture
        switch status {
        case .notDetermined:
            Text("Please authorize camera")

        case .denied, .restricted:
            Label("Camera denied or restricted", systemImage: "video")
                .frame(width: 200)
                .symbolVariant(.slash)
                .font(.headline)
                .padding(32)

        case .authorized:
            switch tab {
            case .photo:
                CameraPhotoOverlay()
            case .video:
                CameraVideoOverlay()
            }

        @unknown default:
            fatalError()
        }
    }
}

#Preview {
    ContentView()
            .preferredColorScheme(.dark)
}

extension URL: Identifiable {
    public var id: String {
        absoluteString
    }
}

extension UIImage: Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

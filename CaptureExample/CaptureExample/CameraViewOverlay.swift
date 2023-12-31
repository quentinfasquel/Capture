//
//  CameraViewOverlay.swift
//  CaptureExample
//
//  Created by Quentin Fasquel on 22/12/2023.
//

import Capture
import SwiftUI

struct CameraPhotoOverlay: View {
    @Environment(\.takePicture) private var takePicture

    var body: some View {
        Color.clear.safeAreaInset(edge: .bottom) {
            CameraButton(style: .photo) {
                takePicture()
            }
        }
    }
}

struct CameraVideoOverlay: View {
    @Environment(\.recordVideo) private var video
    @State private var isRecording: Bool = false
    
    var body: some View {
        Color.clear.safeAreaInset(edge: .bottom) {
            CameraButton(style: .recording($isRecording)) {
                isRecording.toggle()
                if isRecording {
                    video.startRecording()
                } else {
                    video.stopRecording()
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraPhotoOverlay()
    }
    .environmentObject(Camera.default)
}

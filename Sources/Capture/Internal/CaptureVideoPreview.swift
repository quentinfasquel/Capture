//
//  CaptureVideoPreview.swift
//  Capture
//
//  Created by Quentin Fasquel on 16/12/2023.
//

import SwiftUI
#if os(iOS)
import UIKit
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias ViewRepresentable = NSViewRepresentable
#endif

struct CaptureVideoPreview: ViewRepresentable {
    @EnvironmentObject private var camera: Camera
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var isPaused: Bool = false
    
#if os(iOS)
    func makeUIView(context: Context) -> AVCaptureVideoPreviewView {
        let coordinator = context.coordinator
        let previewView = AVCaptureVideoPreviewView(camera.previewLayer)
        coordinator.view = previewView
        return previewView
    }

    func updateUIView(_ view: AVCaptureVideoPreviewView, context: Context) {
        view.videoPreviewLayer.videoGravity = videoGravity
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
#elseif os(macOS)
    func makeNSView(context: Context) -> AVCaptureVideoPreviewView {
        AVCaptureVideoPreviewView(camera.previewLayer)
    }

    func updateNSView(_ nsView: AVCaptureVideoPreviewView, context: Context) {
        nsView.videoPreviewLayer.videoGravity = videoGravity
    }
#endif
}

// MARK: - Capture Video Preview View

#if os(macOS)
final class AVCaptureVideoPreviewView: NSView {
    let videoPreviewLayer: AVCaptureVideoPreviewLayer

    convenience init(session: AVCaptureSession) {
        self.init(AVCaptureVideoPreviewLayer(session: session))
    }

    required init(_ previewLayer: AVCaptureVideoPreviewLayer) {
        videoPreviewLayer = previewLayer
        super.init(frame: .zero)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeBackingLayer() -> CALayer {
        videoPreviewLayer
    }
}
#elseif os(iOS)

final class AVCaptureVideoPreviewView: UIView {
    let pausedView: UIImageView = UIImageView()
    let videoPreviewLayer: AVCaptureVideoPreviewLayer

    convenience init(session: AVCaptureSession) {
        self.init(AVCaptureVideoPreviewLayer(session: session))
    }

    required init(_ previewLayer: AVCaptureVideoPreviewLayer) {
        videoPreviewLayer = previewLayer
        super.init(frame: .zero)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Adding a paused image view
        pausedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pausedView.isHidden = true
        pausedView.contentMode = .scaleAspectFill
        addSubview(pausedView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            layer.addSublayer(videoPreviewLayer)
            videoPreviewLayer.frame = bounds
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds

        if let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            let deviceOrientation = UIDevice.current.orientation
            switch deviceOrientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                connection.videoOrientation = .landscapeRight
            case .landscapeRight:
                connection.videoOrientation = .landscapeLeft
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}

#endif

#if os(iOS)

extension CaptureVideoPreview {

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let previewOutput = AVCaptureVideoDataOutput()
        let dispatchQueue = DispatchQueue(label: "\(bundleIdentifier).CaptureVideoPreview")
        var view: AVCaptureVideoPreviewView?
        var pausedImage: UIImage?

        private var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            view?.videoPreviewLayer
        }

        func pause(session: AVCaptureSession) {
            previewOutput.setSampleBufferDelegate(self, queue: dispatchQueue)
        }

        func resume(session: AVCaptureSession) {
            videoPreviewLayer?.session = session
            view?.pausedView.isHidden = true
            view?.pausedView.image = nil
            pausedImage = nil
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard pausedImage == nil, let imageBuffer = sampleBuffer.imageBuffer else {
                return
            }

            // Generate preview image
            let videoOrientation = output.connection(with: .video)?.videoOrientation ?? .portrait
            let previewImage = createImage(from: imageBuffer, videoOrientation: videoOrientation)
            pausedImage = previewImage

            DispatchQueue.main.async { [view] in
                view?.pausedView.image = previewImage
                view?.pausedView.isHidden = false
            }

            if let session = videoPreviewLayer?.session {
                session.removeOutput(previewOutput)
                previewOutput.setSampleBufferDelegate(nil, queue: nil)
                videoPreviewLayer?.session = nil
            }
        }
        
        private func createImage(
            from imageBuffer: CVImageBuffer,
            videoOrientation: AVCaptureVideoOrientation
        ) -> UIImage {
            let orientation = UIImage.Orientation(videoOrientation)
            let ciImage = CIImage(cvImageBuffer: imageBuffer, options: [.applyOrientationProperty: true])
            return UIImage(ciImage: ciImage, scale: 1, orientation: orientation)
                .fixOrientation()
        }
    }
}

#endif

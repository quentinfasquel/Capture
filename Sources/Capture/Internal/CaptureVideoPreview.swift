//
//  CaptureVideoPreview.swift
//  Capture
//
//  Created by Quentin Fasquel on 16/12/2023.
//

import SwiftUI

struct CaptureVideoPreview: UIViewRepresentable {
    var captureSession: AVCaptureSession
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var isPaused: Bool = false

    func makeUIView(context: Context) -> AVCaptureVideoPreviewView {
        let coordinator = context.coordinator
        let previewView = AVCaptureVideoPreviewView(captureSession: captureSession)
        coordinator.view = previewView
        coordinator.videoPreviewLayer = previewView.videoPreviewLayer
        return previewView
    }

    func updateUIView(_ view: AVCaptureVideoPreviewView, context: Context) {
        if isPaused {
            context.coordinator.pause(session: captureSession)
        } else {
            context.coordinator.resume(session: captureSession)
        }

        view.videoPreviewLayer.videoGravity = videoGravity
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let previewOutput = AVCaptureVideoDataOutput()
        let dispatchQueue = DispatchQueue(label: "\(bundleIdentifier).CaptureVideoPreview")
        var videoPreviewLayer: AVCaptureVideoPreviewLayer?
        var view: AVCaptureVideoPreviewView?
        var pausedImage: UIImage?
        
        func pause(session: AVCaptureSession) {
            previewOutput.setSampleBufferDelegate(self, queue: dispatchQueue)
            session.addOutput(previewOutput)
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

// MARK: - Capture Video Preview View

final class AVCaptureVideoPreviewView: UIView {
    let captureSession: AVCaptureSession
    let pausedView: UIImageView = UIImageView()

    fileprivate init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init(frame: .zero)
        // Adding a paused image view
        pausedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pausedView.isHidden = true
        pausedView.contentMode = .scaleAspectFill
        addSubview(pausedView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            videoPreviewLayer.session = captureSession
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
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

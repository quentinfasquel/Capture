//
//  PhotoOutput.swift
//  Capture
//
//  Created by Quentin Fasquel on 04/01/2025.
//

@preconcurrency import AVFoundation

final class PhotoCapture: NSObject {
    let capturePhotoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<AVCapturePhoto, Error>?

    override init() {
        super.init()
        capturePhotoOutput.maxPhotoQualityPrioritization = .quality
    }

    func capturePhoto() async throws -> AVCapturePhoto {
        let photoSettings = capturePhotoOutput.photoSettings()
        return try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

// MARK: - Photo Capture Delegate

extension PhotoCapture: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            captureContinuation?.resume(throwing: error)
        } else {
            captureContinuation?.resume(returning: photo)
        }
        captureContinuation = nil
    }
}

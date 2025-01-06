//
//  Camera+UIImage.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

@preconcurrency import AVFoundation
import Foundation

extension Camera {

    func takePicture() async -> PlatformImage? {
        do {
            let capturePhoto = try await takePicture() as AVCapturePhoto
            return PlatformImage(photo: capturePhoto)
        } catch {
            return nil
        }
    }

    func takePicture(outputSize: CGSize) async -> PlatformImage? {
        guard let image = await takePicture() else {
            return nil
        }

#if os(iOS)
        return image.fixOrientation().scaleToFill(in: outputSize)
#elseif os(macOS)
        return image.scaleToFill(in: outputSize)
#endif
    }
}

extension Camera {

    func stopRecording() async -> URL? {
        do {
            return try await stopRecording() as URL
        } catch {
            return nil
        }
    }
}

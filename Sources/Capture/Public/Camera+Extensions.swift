//
//  Camera+UIImage.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

extension Camera {
    func takePicture(outputSize: CGSize) async -> PlatformImage? {
        do {
            let capturePhoto = try await takePicture()
            let image = PlatformImage(photo: capturePhoto)
#if os(iOS)
            return image?.fixOrientation().scaleToFill(in: outputSize)
#elseif os(macOS)
            return image?.scaleToFill(in: outputSize)
#endif
        } catch {
            return nil
        }
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

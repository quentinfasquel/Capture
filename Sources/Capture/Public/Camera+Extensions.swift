//
//  Camera+UIImage.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import UIKit.UIImage

extension Camera {
    func takePicture(outputSize: CGSize) async -> UIImage? {
        do {
            let capturePhoto = try await takePicture()
            let image = UIImage(photo: capturePhoto)
            return image?.fixOrientation().scaleToFill(in: outputSize)
        } catch {
            return nil
        }
    }
    
    func stopRecording() async -> URL? {
        do {
            return try await stopRecording() as URL
        } catch {
            return nil
        }
    }
}

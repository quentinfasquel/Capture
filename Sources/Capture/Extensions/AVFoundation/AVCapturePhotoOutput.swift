//
//  AVCapturePhotoOutput.swift
//  Capture
//
//  Created by Quentin Fasquel on 16/12/2023.
//

import AVFoundation

extension AVCapturePhotoOutput {

    func photoSettings() -> AVCapturePhotoSettings {
        let photoSettings: AVCapturePhotoSettings

        if availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
        } else {
            photoSettings = AVCapturePhotoSettings()
        }
        
        // Uncomment to enable flash automatically
        // let isFlashAvailable = deviceInput?.device.isFlashAvailable ?? false
        // photoSettings.flashMode = isFlashAvailable ? .auto : .off
        // photoSettings.isHighResolutionPhotoEnabled = true
        // photoSettings.maxPhotoDimensions = .init(width: , height: )
        photoSettings.photoQualityPrioritization = .balanced

        if let pixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [
                String(kCVPixelBufferPixelFormatTypeKey): pixelFormatType
            ]
        }

        return photoSettings
    }
}

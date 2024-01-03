//
//  NSImage+AVCapturePhoto.swift
//  Capture
//
//  Created by Quentin Fasquel on 02/01/2024.
//

#if os(macOS)
import AVFoundation
import AppKit

extension NSImage {
    public convenience init?(photo: AVCapturePhoto) {
        // Get the pixel buffer from the AVCapturePhoto
        guard let pixelBuffer = photo.pixelBuffer else {
            return nil
        }
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        // Create an NSBitmapImageRep from the CIImage
        let bitmapImageRep = NSCIImageRep(ciImage: ciImage)
        // Create an NSImage from the NSBitmapImageRep
        let imageSize = NSSize(width: bitmapImageRep.pixelsWide, height: bitmapImageRep.pixelsHigh)
        self.init(size: imageSize)
        self.addRepresentation(bitmapImageRep)
    }
}
#endif

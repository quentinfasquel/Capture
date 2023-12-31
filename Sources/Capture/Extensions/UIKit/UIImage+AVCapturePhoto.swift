//
//  UIImage+AVCapturePhoto.swift
//  Capture
//
//  Created by Quentin Fasquel on 07/12/2023.
//

import UIKit.UIImage

extension UIImage {
    
    /// Create image with proper orientation
    public convenience init?(photo: AVCapturePhoto) {
        guard let cgImage = photo.cgImageRepresentation(),
              let rawOrientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgOrientation = CGImagePropertyOrientation(rawValue: rawOrientation) else {
            return nil
        }
 
        let imageOrientation = UIImage.Orientation(cgOrientation)
        self.init(cgImage: cgImage, scale: 1, orientation: imageOrientation)
    }
}

extension UIImage.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

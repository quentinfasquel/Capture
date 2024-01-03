//
//  UIImage+AVCaptureVideoOrientation.swift
//  Capture
//
//  Created by Quentin Fasquel on 24/12/2023.
//

#if canImport(UIKit)
import AVFoundation
import UIKit

extension UIImage.Orientation {
    public init(_ videoOrientation: AVCaptureVideoOrientation) {
        switch videoOrientation {
        case .portrait:
            self = .up
        case .portraitUpsideDown:
            self = .down
        case .landscapeLeft:
            self = .left
        case .landscapeRight:
            self = .right
        @unknown default:
            fatalError()
        }
    }
}
#endif

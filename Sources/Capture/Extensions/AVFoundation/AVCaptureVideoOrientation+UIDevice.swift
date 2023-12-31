//
//  AVCaptureVideoOrientation+UIDevice.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import AVFoundation
import UIKit.UIDevice

extension AVCaptureVideoOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            self = AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            self = AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            self = AVCaptureVideoOrientation.landscapeLeft
        default:
            self = .portrait
        }
    }
}

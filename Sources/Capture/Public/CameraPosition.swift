//
//  CameraPosition.swift
//  Capture
//
//  Created by Quentin Fasquel on 16/12/2023.
//

import Foundation

public typealias CameraPosition = AVCaptureDevice.Position

public extension CameraPosition {
    mutating func toggle() {
        if self == .front {
            self = .back
        } else if self == .back {
            self = .front
        } else {
            // Do nothing
        }
    }
}

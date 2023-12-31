//
//  AVCaptureDeviceInput.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import AVFoundation
import OSLog

extension AVCaptureDeviceInput {
    convenience init?(device: AVCaptureDevice?, logger: Logger) {
        guard let device else {
            return nil
        }
        do {
            try self.init(device: device)
        } catch let error {
            logger.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
}

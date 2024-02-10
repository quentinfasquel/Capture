//
//  CameraConfigurationWarning.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import Foundation

enum CameraConfigurationWarning {
    case audioDeviceNotFound
    case cameraDeviceNotSet
    case cannotAddAudioInput
    case cannotAddPhotoOutput
    case cannotAddVideoDataOutput
    case cannotAddVideoFileOutput
    case cannotAddVideoInput
    case cannotSetSessionPreset
}

extension Camera {

    func log(_ warning: CameraConfigurationWarning) {
        switch warning {
        case .audioDeviceNotFound:
            logger.warning("Audio device not found")
        case .cameraDeviceNotSet:
            logger.warning("Camera device not found")
        case .cannotAddAudioInput:
            logger.warning("Cannot add audio input")
        case .cannotAddPhotoOutput:
            logger.warning("Cannot add photo output")
        case .cannotAddVideoDataOutput:
            logger.warning("Cannot add video data output")
        case .cannotAddVideoFileOutput:
            logger.warning("Cannot add video file output")
        case .cannotAddVideoInput:
            logger.warning("Cannot add video input")
        case .cannotSetSessionPreset:
            logger.warning("Cannot set request session preset")
        }
    }
}

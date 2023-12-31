//
//  AVCaptureVideoFileOutputRecordingDelegate.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import Foundation

protocol AVCaptureVideoFileOutputRecordingDelegate: AnyObject {

    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didStartRecordingTo outputURL: URL,
        from connections: [AVCaptureConnection])
    
    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didFinishRecordingTo outputURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?)
}

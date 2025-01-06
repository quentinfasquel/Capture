//
//  MovieOutput.swift
//  Capture
//
//  Created by Quentin Fasquel on 04/01/2025.
//

@preconcurrency import AVFoundation

final class MovieCapture: NSObject, @unchecked Sendable {
    private(set) var movieOutput: MovieCaptureOutput?
    private var recordingSettings: RecordingSettings?
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    private var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    @discardableResult
    func configureOutput(settings: RecordingSettings?) -> MovieCaptureOutput? {
        if movieOutput == nil || recordingSettings != settings {
            recordingSettings = settings
            if let settings {
                movieOutput = AVCaptureVideoFileOutput(
                    audioSettings: settings.audio,
                    videoSettings: settings.video
                )
            } else {
                movieOutput = AVCaptureMovieFileOutput()
            }
            return movieOutput
        }

        return nil
    }

    func startRecording() {
        guard let movieOutput else {
            assertionFailure("movieOutput is nil")
            return
        }

        let outputURL = temporaryDirectory.appendingPathComponent(
            "\(Date.now)", conformingTo: movieOutput.fileType.utType)

        if let videoOutput = movieOutput as? AVCaptureVideoFileOutput {
            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        } else if let videoOutput = movieOutput as? AVCaptureMovieFileOutput {
            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
    }

    func stopRecording() async throws -> URL {
        guard let movieOutput else {
            throw CameraError.missingVideoOutput
        }

        return try await withCheckedThrowingContinuation { continuation in
            recordingContinuation = continuation
            movieOutput.stopRecording()
        }
    }

    private func didStartRecording() {

    }

    private func didStopRecording(outputFileURL: URL, error: Error?) {
        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: outputFileURL)
        }
        recordingContinuation = nil
    }
}

// MARK: - File Output Recording Delegates

extension MovieCapture: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        didStartRecording()
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        didStopRecording(outputFileURL: outputFileURL, error: error)
    }
}

extension MovieCapture: AVCaptureVideoFileOutputRecordingDelegate {
    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didStartRecordingTo outputURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        didStartRecording()
    }
    
    func videoFileOutput(
        _ output: AVCaptureVideoFileOutput,
        didFinishRecordingTo outputURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        didStopRecording(outputFileURL: outputURL, error: error)
    }
}

// MARK: -

protocol MovieCaptureOutput {
    var captureOutputs: [AVCaptureOutput] { get }
    var fileType: AVFileType { get }

    func stopRecording()
}

extension AVCaptureMovieFileOutput: MovieCaptureOutput {
    var captureOutputs: [AVCaptureOutput] { [self] }
    var fileType: AVFileType { .mov }
}

extension AVCaptureVideoFileOutput: MovieCaptureOutput {
    var captureOutputs: [AVCaptureOutput] { [audioDataOutput, videoDataOutput] }
    var fileType: AVFileType { Capture.fileType(for: videoSettings.codec) ?? .mov }
}

extension AVCaptureSession {
    func removeOutput(_ output: MovieCaptureOutput) {
        output.captureOutputs.forEach { captureOutput in
            removeOutput(captureOutput)
        }
    }

    func canAddOutput(_ output: MovieCaptureOutput) -> Bool {
        output.captureOutputs.reduce(true) { partialResult, captureOutput in
            partialResult && canAddOutput(captureOutput)
        }
    }

    func addOutput(_ output: MovieCaptureOutput) {
        output.captureOutputs.forEach { captureOutput in
            addOutput(captureOutput)
        }
    }
}

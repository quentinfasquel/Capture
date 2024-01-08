//
//  AVCaptureFileOutput.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import AVFoundation

protocol CaptureRecording: NSObject {
    func stopRecording()
}

extension AVCaptureMovieFileOutput: CaptureRecording {
}

///
/// A replacement for `AVCaptureMovieFileOutput`
///
final class AVCaptureVideoFileOutput: NSObject, CaptureRecording {

    private let outputQueue = DispatchQueue(label: "\(bundleIdentifier).CaptureVideoFileOutput")
    fileprivate let audioDataOutput = AVCaptureAudioDataOutput()
    fileprivate let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var assetWriter: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var isRecording: Bool = false
    private var isStoppingRecording: Bool = false

    private weak var delegate: AVCaptureVideoFileOutputRecordingDelegate?

    private var startSourceTime: CMTime?
    private var lastVideoSourceTime: CMTime?
    private var canWrite: Bool {
        isRecording && !isStoppingRecording
    }

    override init() {
        super.init()
        audioDataOutput.setSampleBufferDelegate(self, queue: outputQueue)
        videoDataOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }
    
    deinit {
        print(#function, self)
    }
    
    // MARK: - Recording
        
    public private(set) var audioSettings = AudioSettings(
        formatID: kAudioFormatMPEG4AAC,
        sampleRate: 44100,
        numberOfChannels: 2,
        audioFileType: kAudioFileMPEG4Type,
//        encoderAudioQuality: .high,
        encoderBitRate: .bitRate(128000)
    )
    
    public private(set) var videoSettings = VideoSettings(
        codec: .h264,
        width: 0,
        height: 0,
        scalingMode: .resizeAspectFill
    )
    
    public func configureOutput(audioSettings: AudioSettings? = nil, videoSettings: VideoSettings) {
        if let audioSettings {
            self.audioSettings = audioSettings
        }
        self.videoSettings = videoSettings
    }
    
    func startRecording(to outputURL: URL, recordingDelegate: AVCaptureVideoFileOutputRecordingDelegate) {
        guard !isRecording else {
            return
        }

        let outputFileType = fileType(for: videoSettings.codec) ?? .mov
        assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
        delegate = recordingDelegate

        guard let assetWriter else {
            logger.error("AVAssetWriter: cannot init")
            return
        }

        let audioSettings = audioSettings.dictionaryRepresentation
        let videoSettings = videoSettings.dictionaryRepresentation

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        if assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
            videoWriterInput = videoInput
        } else {
            logger.error("AVAssetWriter: cannot add video input")
        }

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        
        if assetWriter.canAdd(audioInput) {
            assetWriter.add(audioInput)
            audioWriterInput = audioInput
        } else {
            logger.error("AVAssetWriter: cannot add audio input")
        }

        guard assetWriter.startWriting() else {
            logger.error("AVAssetWriter: cannot start writing")
            return
        }

        isRecording = true
        
        DispatchQueue.main.async { [self] in
            delegate?.videoFileOutput(
                self,
                didStartRecordingTo: outputURL,
                from: videoDataOutput.connections
            )
        }
    }
    
    func stopRecording() {
        guard isRecording, !isStoppingRecording, let assetWriter else {
            return
        }

        isStoppingRecording = true

        audioWriterInput?.markAsFinished()
        audioWriterInput = nil
        videoWriterInput?.markAsFinished()
        videoWriterInput = nil

        if let endSourceTime = lastVideoSourceTime {
            assetWriter.endSession(atSourceTime: endSourceTime)
            lastVideoSourceTime = nil
        }

        assetWriter.finishWriting { [self] in
            isRecording = false
            isStoppingRecording = false
            startSourceTime = nil

            DispatchQueue.main.async { [self] in
                delegate?.videoFileOutput(self,
                    didFinishRecordingTo: assetWriter.outputURL,
                    from: videoDataOutput.connections,
                    error: assetWriter.error
                )
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AVCaptureVideoFileOutput: AVCaptureAudioDataOutputSampleBufferDelegate {
    // Common method with AVCaptureVideoDataOutputSampleBufferDelegate
}

extension AVCaptureVideoFileOutput: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard canWrite, let assetWriter, CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        if output == videoDataOutput {
            if let videoWriterInput, videoWriterInput.isReadyForMoreMediaData {
                let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if startSourceTime == nil {
                    startSourceTime = sourceTime
                    assetWriter.startSession(atSourceTime: sourceTime)
                }

                videoWriterInput.append(sampleBuffer)
                lastVideoSourceTime = sourceTime
            }
        }
        
        if output == audioDataOutput, startSourceTime != nil {
            if let audioWriterInput, audioWriterInput.isReadyForMoreMediaData {
                audioWriterInput.append(sampleBuffer)
            }
        }
    }
}

// MARK: - AVCaptureSession Output

extension AVCaptureSession {

    func canAddOutput(_ output: AVCaptureVideoFileOutput) -> Bool {
        canAddOutput(output.audioDataOutput) && canAddOutput(output.videoDataOutput)
    }
    
    func addOutput(_ output: AVCaptureVideoFileOutput) {
        addOutput(output.audioDataOutput)
        addOutput(output.videoDataOutput)
    }
    
    func removeOutput(_ output: AVCaptureVideoFileOutput) {
        removeOutput(output.audioDataOutput)
        removeOutput(output.videoDataOutput)
    }
}

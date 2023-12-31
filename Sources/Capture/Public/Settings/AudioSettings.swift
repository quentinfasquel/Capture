
//
//  AudioSettings.swift
//  Capture
//
//  Created by Quentin Fasquel on 24/12/2023.
//

import AVFoundation

extension AudioSettings {
    public static let `default` = AudioSettings(
        formatID: kAudioFormatMPEG4AAC,
        sampleRate: 44100,
        numberOfChannels: 2,
        audioFileType: kAudioFileMPEG4Type,
        encoderBitRate: .bitRate(128000)
    )
}

public struct AudioSettings: Equatable {
    
    /// value is an integer (format ID) from CoreAudioTypes.h
    public var formatID: AudioFormatID

    /// value is floating point in Hertz
    public var sampleRate: Float

    /// value is an integer
    public var numberOfChannels: Int

    // MARK: - Linear PCM properties

    /// value is an integer, one of: 8, 16, 24, 32
    public var linearPCMBitDepth: Int?

    /// value is a boolean
    public var linearPCMIsBigEndian: Bool?

    /// value is a boolean
    public var linearPCMIsFloat: Bool?

    /// value is a boolean
    public var linearPCMIsNonInterleaved: Bool?

    // MARK: - Audio file type

    /// value is an integer (audio file type) from AudioFile.h
    public var audioFileType: AudioFileTypeID

    // MARK: - Encoder properties

    /// value is an integer from enum AVAudioQuality
    public var encoderAudioQuality: AVAudioQuality?

    /// value is an integer from enum AVAudioQuality. only relevant for AVAudioBitRateStrategy_Variable
    public var encoderAudioQualityForVBR: AVAudioQuality?

    /// value is an integer.
    public var encoderBitRate: EncoderBitRate?

    /// value is an AVAudioBitRateStrategy constant. see below.
    public var encoderBitRateStrategy: AudioBitRateStrategy?

    /// value is an integer from 8 to 32
    public var encoderBitDepthHint: Int?

    // sample rate converter property keys

    /// value is an AVSampleRateConverterAlgorithm constant. see below.
    public var sampleRateConverterAlgorithm: SampleRateConverterAlgorithm?

    /// value is an integer from enum AVAudioQuality
    public var sampleRateConverterAudioQuality: AVAudioQuality?

    // MARK: - channel layout

    /// value is an NSData containing an AudioChannelLayout
    public var channelLayout: Data?
    
    // MARK: - Init
    
    public init(
        formatID: AudioFormatID,
        sampleRate: Float,
        numberOfChannels: Int,
        linearPCMBitDepth: Int? = nil,
        linearPCMIsBigEndian: Bool? = nil,
        linearPCMIsFloat: Bool? = nil,
        linearPCMIsNonInterleaved: Bool? = nil,
        audioFileType: AudioFileTypeID,
        encoderAudioQuality: AVAudioQuality? = nil,
        encoderAudioQualityForVBR: AVAudioQuality? = nil,
        encoderBitRate: EncoderBitRate? = nil,
        encoderBitRateStrategy: AudioBitRateStrategy? = nil,
        encoderBitDepthHint: Int? = nil,
        sampleRateConverterAlgorithm: SampleRateConverterAlgorithm? = nil,
        sampleRateConverterAudioQuality: AVAudioQuality? = nil,
        channelLayout: Data? = nil
    ) {
        self.formatID = formatID
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        self.linearPCMBitDepth = linearPCMBitDepth
        self.linearPCMIsBigEndian = linearPCMIsBigEndian
        self.linearPCMIsFloat = linearPCMIsFloat
        self.linearPCMIsNonInterleaved = linearPCMIsNonInterleaved
        self.audioFileType = audioFileType
        self.encoderAudioQuality = encoderAudioQuality
        self.encoderAudioQualityForVBR = encoderAudioQualityForVBR
        self.encoderBitRate = encoderBitRate
        self.encoderBitRateStrategy = encoderBitRateStrategy
        self.encoderBitDepthHint = encoderBitDepthHint
        self.sampleRateConverterAlgorithm = sampleRateConverterAlgorithm
        self.sampleRateConverterAudioQuality = sampleRateConverterAudioQuality
        self.channelLayout = channelLayout
    }
    
    // MARK: - Property Values

    public enum EncoderBitRate: Equatable {
        case bitRate(Int)
        case bitRatePerChannel(Int)
    }
    
    /// values for AVEncoderBitRateStrategyKey
    public enum AudioBitRateStrategy: String {
        case constant
        case longTermAverage
        case variableConstrained
        case variable
    }

    /// values for AVSampleRateConverterAlgorithmKey
    public enum SampleRateConverterAlgorithm: String {
        case normal
        case mastering
        case minimumPhase
    }
}

// MARK: -

extension AudioSettings.EncoderBitRate {
    var bitRateValue: Int? {
        guard case .bitRate(let value) = self else { return nil }
        return value
    }
    
    var perChannelValue: Int? {
        guard case .bitRatePerChannel(let value) = self else { return nil }
        return value
    }
}

extension AudioSettings.AudioBitRateStrategy {
    public var rawValue: String {
        switch self {
        case .constant:
            AVAudioBitRateStrategy_Constant
        case .longTermAverage:
            AVAudioBitRateStrategy_LongTermAverage
        case .variableConstrained:
            AVAudioBitRateStrategy_VariableConstrained
        case .variable:
            AVAudioBitRateStrategy_Variable
        }
    }
}

extension AudioSettings.SampleRateConverterAlgorithm {
    public var rawValue: String {
        switch self {
        case .normal:
            AVSampleRateConverterAlgorithm_Normal
        case .mastering:
            AVSampleRateConverterAlgorithm_Mastering
        case .minimumPhase:
            AVSampleRateConverterAlgorithm_MinimumPhase
        }
    }
}

// MARK: -

extension AudioSettings {

    public var dictionaryRepresentation: [String: Any] {
        return [
            AVFormatIDKey: formatID,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: numberOfChannels,
            AVLinearPCMBitDepthKey: linearPCMBitDepth,
            AVLinearPCMIsBigEndianKey: linearPCMIsBigEndian,
            AVLinearPCMIsFloatKey: linearPCMIsFloat,
            AVLinearPCMIsNonInterleaved: linearPCMIsNonInterleaved,
//            AVAudioFileTypeKey: audioFileType,
            AVEncoderAudioQualityKey: encoderAudioQuality,
            AVEncoderAudioQualityForVBRKey: encoderAudioQualityForVBR,
            AVEncoderBitRateKey: encoderBitRate?.bitRateValue,
            AVEncoderBitRatePerChannelKey: encoderBitRate?.perChannelValue,
            AVEncoderBitRateStrategyKey: encoderBitRateStrategy?.rawValue,
            AVEncoderBitDepthHintKey: encoderBitDepthHint,
            AVSampleRateConverterAlgorithmKey: sampleRateConverterAlgorithm?.rawValue,
            AVSampleRateConverterAudioQualityKey: sampleRateConverterAudioQuality,
            AVChannelLayoutKey: channelLayout as NSData?
        ].removingNilValues()
    }
}


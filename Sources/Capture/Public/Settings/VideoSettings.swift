//
//  VideoSettings.swift
//  Capture
//
//  Created by Quentin Fasquel on 24/12/2023.
//

import AVFoundation

extension VideoSettings {
    public static let `default` = VideoSettings(
        codec: .h264,
        width: 720,
        height: 960,
        scalingMode: .resizeAspectFill
    )
}

public struct VideoSettings: Equatable {

    /// A video codec type (for instance
    public var codec: AVVideoCodecType
    
    /// - note: For best results, always use even number values when encoding to AVVideoCodecTypeH264 or any other format that uses 4:2:0 downsampling
    public var width: Int
    
    /// - note: For best results, always use even number values when encoding to AVVideoCodecTypeH264 or any other format that uses 4:2:0 downsampling
    public var height: Int
    
    /// The aspect ratio of the pixels in the video frame
    /// - note:If no value is specified for this key, the default value for the codec is used.  Usually this is 1:1, meaning square pixels.
    public var pixelAspectRatio: PixelAspectRatio?
    
    ///
    public var cleanAperture: CleanAperture?
    
    ///
    public var scalingMode: ScalingMode = .resizeAspectFill
    
    ///
    public var colorProperties: ColorProperties?

    ///
    public var allowWideColor: Bool?
    
    ///
    public var compressionProperties: CompressionProperties?
    
    /// See VideoToolbox/VTCompressionProperties.h for additional profiles/levels that can used as the value of this key.
    public var profileLevel: ProfileLevel?
    
    // MARK: - Init
    
    public init(
        codec: AVVideoCodecType, 
        width: Int,
        height: Int,
        pixelAspectRatio: PixelAspectRatio? = nil,
        cleanAperture: CleanAperture? = nil,
        scalingMode: ScalingMode,
        colorProperties: ColorProperties? = nil,
        allowWideColor: Bool? = nil,
        compressionProperties: CompressionProperties? = nil,
        profileLevel: ProfileLevel? = nil
    ) {
        self.codec = codec
        self.width = width
        self.height = height
        self.pixelAspectRatio = pixelAspectRatio
        self.cleanAperture = cleanAperture
        self.scalingMode = scalingMode
        self.colorProperties = colorProperties
        self.allowWideColor = allowWideColor
        self.compressionProperties = compressionProperties
        self.profileLevel = profileLevel
    }
}

extension VideoSettings {
    
    // MARK: -
    
    public struct PixelAspectRatio: Equatable {
        ///
        public var horizontalSpacing: Int

        ///
        public var verticalSpacing: Int
    }

    // MARK: -
    
    public struct CleanAperture: Equatable {
        ///
        public var width: Int
        ///
        public var height: Int
        ///
        public var horizontalOffset: Int = 0
        ///
        public var verticalOffset: Int = 0
    }

    // MARK: -
    
    public enum ScalingMode: String {
        // Crop to remove edge processing region; preserve aspect ratio of cropped source by reducing specified width or height if necessary.
        // Will not scale a small source up to larger dimensions.
        case fit
        // Crop to remove edge processing region; scale remainder to destination area.
        // Does not preserve aspect ratio.
        case resize
        // Preserve aspect ratio of the source, and fill remaining areas with black to fit destination dimensions.
        case resizeAspect
        // Preserve aspect ratio of the source, and crop picture to fit destination dimensions.
        case resizeAspectFill
    }

    // MARK: -

    public struct ColorProperties: Equatable {
        ///
        public var colorPrimaries: ColorPrimaries

        ///
        public var transferFunction: TransferFunction
        
        ///
        public var yCbCrMatrix: YCbCrMatrix

        public enum ColorPrimaries: String {
            case ITU_R_709_2
            case SMPTE_C
            case P3_D65
            case ITU_R_2020
        }

        public enum TransferFunction: String {
            case linear
            case ITU_R_709_2
            case ITU_R_2100_HLG
            case SMPTE_ST_2084_PQ
        }
        
        public enum YCbCrMatrix: String {
            case ITU_R_709_2
            case ITU_R_601_4
            case ITU_R_2020
        }
    }
    
    // MARK: -

    public struct CompressionProperties: Equatable {
        // NSNumber (bits per second, H.264 only)
        public var averageBitRate: String?

        /// A floating-point value between 0.0-1.0. For JPEG, HEIC and Apple ProRAW only.
        /// - note: With HEIC and Apple ProRAW, 1.0 indicates lossless compression
        public var quality: Float?

        // NSNumber (frames, 1 means key frames only, H.264 only)
        public var maxKeyFrameInterval: Int?

        // NSNumber (seconds, 0.0 means no limit, H.264 only)
        public var maxKeyFrameIntervalDuration: TimeInterval?
        
        // NSNumber (8-16)
        public var appleProRAWBitDepthKey: Int?

        // NSNumber (BOOL)
        public var allowFrameReorderingKey: Bool?
    }

    public enum ProfileLevel: String {
        case H264Baseline30
        case H264Baseline31
        case H264Baseline41
        case H264BaselineAutoLevel
        case H264Main30
        case H264Main31
        case H264Main32
        case H264Main41
        case H264MainAutoLevel
        case H264High40
        case H264High41
        case H264HighAutoLevel
    }
}

// MARK: -

extension VideoSettings.PixelAspectRatio {
    var dictionaryRepresentation: [String: Any] {
        return [
            AVVideoPixelAspectRatioHorizontalSpacingKey: horizontalSpacing,
            AVVideoPixelAspectRatioVerticalSpacingKey: verticalSpacing
        ]
    }
}
extension VideoSettings.CleanAperture {
    var dictionaryRepresentation: [String: Any] {
        return [
            AVVideoCleanApertureWidthKey: width,
            AVVideoCleanApertureHeightKey: height,
            AVVideoCleanApertureHorizontalOffsetKey: horizontalOffset,
            AVVideoCleanApertureVerticalOffsetKey: verticalOffset
        ]
    }
}

extension VideoSettings.ScalingMode {
    public var rawValue: String {
        switch self {
        case .fit:
            AVVideoScalingModeFit
        case .resize:
            AVVideoScalingModeResize
        case .resizeAspect:
            AVVideoScalingModeResizeAspect
        case .resizeAspectFill:
            AVVideoScalingModeResizeAspectFill
        }
    }
}

extension VideoSettings.ColorProperties {
    var dictionaryRepresentation: [String: Any] {
        return [
            AVVideoColorPrimariesKey: colorPrimaries.rawValue,
            AVVideoTransferFunctionKey: transferFunction.rawValue,
            AVVideoYCbCrMatrixKey: yCbCrMatrix.rawValue
        ].removingNilValues()
    }
}

extension VideoSettings.ColorProperties.ColorPrimaries {
    public var rawValue: String {
        switch self {
        case .ITU_R_709_2:
            AVVideoColorPrimaries_ITU_R_709_2
        case .SMPTE_C:
            AVVideoColorPrimaries_SMPTE_C
        case .P3_D65:
            AVVideoColorPrimaries_P3_D65
        case .ITU_R_2020:
            AVVideoColorPrimaries_ITU_R_2020
        }
    }
}

extension VideoSettings.ColorProperties.TransferFunction {
    public var rawValue: String {
        switch self {
        case .linear:
            AVVideoTransferFunction_Linear
        case .ITU_R_709_2:
            AVVideoTransferFunction_ITU_R_709_2
        case .ITU_R_2100_HLG:
            AVVideoTransferFunction_ITU_R_2100_HLG
        case .SMPTE_ST_2084_PQ:
            AVVideoTransferFunction_SMPTE_ST_2084_PQ
        }
    }
}

extension VideoSettings.ColorProperties.YCbCrMatrix {
    public var rawValue: String {
        switch self {
        case .ITU_R_709_2:
            AVVideoYCbCrMatrix_ITU_R_709_2
        case .ITU_R_601_4:
            AVVideoYCbCrMatrix_ITU_R_601_4
        case .ITU_R_2020:
            AVVideoYCbCrMatrix_ITU_R_2020
        }
    }
}

extension VideoSettings.ProfileLevel {
    public var rawValue: String {
        switch self {
        case .H264Baseline30:
            AVVideoProfileLevelH264Baseline30
        case .H264Baseline31:
            AVVideoProfileLevelH264Baseline31
        case .H264Baseline41:
            AVVideoProfileLevelH264Baseline41
        case .H264BaselineAutoLevel:
            AVVideoProfileLevelH264BaselineAutoLevel
        case .H264Main30:
            AVVideoProfileLevelH264Main30
        case .H264Main31:
            AVVideoProfileLevelH264Main31
        case .H264Main32:
            AVVideoProfileLevelH264Main32
        case .H264Main41:
            AVVideoProfileLevelH264Main41
        case .H264MainAutoLevel:
            AVVideoProfileLevelH264MainAutoLevel
        case .H264High40:
            AVVideoProfileLevelH264High40
        case .H264High41:
            AVVideoProfileLevelH264High41
        case .H264HighAutoLevel:
            AVVideoProfileLevelH264HighAutoLevel
        }
    }
}

// MARK: -

extension VideoSettings {
    public var dictionaryRepresentation: [String: Any] {
        return [
            AVVideoCodecKey: codec.rawValue,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoPixelAspectRatioKey: pixelAspectRatio?.dictionaryRepresentation,
            AVVideoCleanApertureKey: cleanAperture?.dictionaryRepresentation,
            AVVideoScalingModeKey: scalingMode.rawValue,
            AVVideoColorPropertiesKey: colorProperties?.dictionaryRepresentation,
            AVVideoAllowWideColorKey: allowWideColor
        ].removingNilValues()
    }
}

//
//  AVFileType.swift
//  Capture
//
//  Created by Quentin Fasquel on 02/01/2024.
//

import AVFoundation

func fileType(for videoCodec: AVVideoCodecType) -> AVFileType? {
    switch videoCodec {
    case .proRes422:
        return .mov
    case .proRes4444:
        return .mov
    case .proRes422HQ:
        return .mov
    case .proRes422LT:
        return .mov
    case .proRes422Proxy:
        return .mov
    case .h264:
        return .mp4
    case .hevc, .hevcWithAlpha:
        return .mp4
    case .jpeg:
        return .jpg
    default:
        return nil
    }
}

// MARK: - AudioFormatID

func fileType(for audioFormat: AudioFormatID) -> AVFileType? {
    switch audioFormat {
    case kAudioFormatLinearPCM:
        return .wav
    case kAudioFormatAC3:
        return .ac3
    case kAudioFormat60958AC3:
        return .ac3
//    case kAudioFormatAppleIMA4:
//        return .ima4
    case kAudioFormatMPEG4AAC:
        return .m4a
    case kAudioFormatMPEG4CELP:
        return .m4a
    case kAudioFormatMPEG4HVXC:
        return .m4a
    case kAudioFormatMPEG4TwinVQ:
        return .m4a
    case kAudioFormatMACE3:
        return .caf
    case kAudioFormatMACE6:
        return .caf
    case kAudioFormatULaw:
        return .au
    case kAudioFormatALaw:
        return nil
//    case kAudioFormatQDesign:
//        return .qdm
//    case kAudioFormatQDesign2:
//        return .qd2
//    case kAudioFormatQUALCOMM:
//        return .qcp
//    case kAudioFormatMPEGLayer1:
//        return .mp1
//    case kAudioFormatMPEGLayer2:
//        return .mp2
    case kAudioFormatMPEGLayer3:
        return .mp3
//    case kAudioFormatTimeCode:
//        return nil
//    case kAudioFormatMIDIStream:
//        return .mid
    case kAudioFormatParameterValueStream:
        return nil
    case kAudioFormatAppleLossless:
        return .m4a
    case kAudioFormatMPEG4AAC_HE:
        return .m4a
    case kAudioFormatMPEG4AAC_LD:
        return .m4a
    case kAudioFormatMPEG4AAC_ELD:
        return .m4a
    case kAudioFormatMPEG4AAC_ELD_SBR:
        return .m4a
    case kAudioFormatMPEG4AAC_ELD_V2:
        return .m4a
    case kAudioFormatMPEG4AAC_HE_V2:
        return .m4a
    case kAudioFormatMPEG4AAC_Spatial:
        return .m4a
    case kAudioFormatMPEGD_USAC:
        return .m4a
    case kAudioFormatAMR:
        return .amr
    case kAudioFormatAMR_WB:
        return .amr
//    case kAudioFormatAudible:
//        return .aa
    case kAudioFormatiLBC:
        return .aiff
//    case kAudioFormatDVIIntelIMA:
//        return .ima4
    case kAudioFormatMicrosoftGSM:
        return .wav
    case kAudioFormatAES3:
        return .aiff
    case kAudioFormatEnhancedAC3:
        return .eac3
//    case kAudioFormatFLAC:
//        return AVFileType("flac")
//    case kAudioFormatOpus:
//        return AVFileType("opus")
    default:
        return nil
    }
}


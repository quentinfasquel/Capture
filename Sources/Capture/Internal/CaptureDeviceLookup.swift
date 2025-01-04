//
//  CaptureDeviceLookup.swift
//  Capture
//
//  Created by Quentin Fasquel on 04/01/2025.
//

@preconcurrency import AVFoundation

final class CaptureDeviceLookup {

    private lazy var discoverySession: AVCaptureDevice.DiscoverySession = {
#if os(iOS)
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInLiDARDepthCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInTrueDepthCamera,
            .builtInWideAngleCamera,
        ]
        if #available(iOS 17, *) {
            deviceTypes.append(.continuityCamera)
        }
#elseif os(macOS)
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .deskViewCamera,
        ]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.continuityCamera)
            deviceTypes.append(.external)
        }
#endif
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
    }()

    var backCaptureDevices: [AVCaptureDevice] {
        discoverySession.devices.filter { $0.position == .back }
    }

    var frontCaptureDevices: [AVCaptureDevice] {
        discoverySession.devices.filter { $0.position == .front }
    }

    var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += discoverySession.devices
#else

        let defaultDevice = AVCaptureDevice.default(for: .video)
        if let defaultDevice {
            devices.append(defaultDevice)
        }

        if let backDevice = backCaptureDevices.first, backDevice != defaultDevice {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first, frontDevice != defaultDevice {
            devices += [frontDevice]
        }
#endif
        return devices
    }

    var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices.filter { $0.isConnected && !$0.isSuspended }.unique()
    }
}

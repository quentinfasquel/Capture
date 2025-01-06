//
//  RecordVideoAction.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import SwiftUI

public struct RecordVideoAction: Sendable {

    var start: @Sendable () async -> Void = {
        assertionFailure("@Environment(\\.recordVideo) must be accessed from a camera overlay view")
    }

    var stop: @Sendable () async -> Void = {
        assertionFailure("@Environment(\\.recordVideo) must be accessed from a camera overlay view")
    }
    
    public func startRecording() {
        Task { await start() }
    }

    public func stopRecording() {
        Task { await stop() }
    }
}

extension EnvironmentValues {
    @Entry public internal(set) var recordVideo: RecordVideoAction = .init()
}

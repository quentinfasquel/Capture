//
//  RecordingSettings.swift
//  Capture
//
//  Created by Quentin Fasquel on 27/12/2023.
//

import SwiftUI

struct RecordingSettings: Equatable {
    var audio: AudioSettings = .default
    var video: VideoSettings = .default
    
    func updating(audio: AudioSettings) -> Self {
        var settings = self
        settings.audio = audio
        return settings
    }

    func updating(video: VideoSettings) -> Self {
        var settings = self
        settings.video = video
        return settings
    }
}

extension EnvironmentValues {
    @Entry internal var recordingSettings: RecordingSettings?

    public var recordingAudioSettings: AudioSettings {
        get { recordingSettings?.audio ?? .default }
        set { recordingSettings = recordingSettings?.updating(audio: newValue) ?? RecordingSettings(audio: newValue)
        }
    }
    
    public var recordingVideoSettings: VideoSettings {
        get { recordingSettings?.video ?? .default }
        set { recordingSettings = recordingSettings?.updating(video: newValue) ?? RecordingSettings(video: newValue) }
    }
}

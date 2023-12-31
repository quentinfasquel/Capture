//
//  TakePictureAction.swift
//  Capture
//
//  Created by Quentin Fasquel on 07/11/2023.
//

import SwiftUI

public struct TakePictureAction {

    var handler: () async -> Void = {
        assertionFailure("@Environment(\\.takePicture) must be accessed from a camera overlay view")
    }

    public func callAsFunction() {
        Task { await handler() }
    }
}

private enum TakePictureEnvironmentKey: EnvironmentKey {
    static var defaultValue: TakePictureAction = .init()
}

extension EnvironmentValues {
    
    public internal(set) var takePicture: TakePictureAction {
        get { self[TakePictureEnvironmentKey.self] }
        set { self[TakePictureEnvironmentKey.self] = newValue }
    }

}

//
//  UIScreen+Orientation.swift
//  Capture
//
//  Created by Quentin Fasquel on 07/12/2023.
//

#if canImport(UIKit)
import UIKit.UIScreen

extension UIScreen {

    var deviceOrientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}
#endif

//
//  UIImage+Normalized.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import UIKit.UIImage

extension UIImage {
    public func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

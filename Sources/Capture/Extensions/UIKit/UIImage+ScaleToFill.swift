//
//  UIImage+ScaleToFill.swift
//  Capture
//
//  Created by Quentin Fasquel on 15/11/2023.
//

import func AVFoundation.AVMakeRect
import UIKit.UIImage

extension UIImage {

    public func scaleToFill(in targetSize: CGSize) -> UIImage {
        guard targetSize != .zero else {
            return self
        }

        let image = self
        let imageBounds = CGRect(origin: .zero, size: size)
        let cropRect = AVMakeRect(aspectRatio: targetSize, insideRect: imageBounds)
        let rendererFormat = UIGraphicsImageRendererFormat(); rendererFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        return renderer.image { context in
            // UIImage and CGContext coordinates are flipped.
            var transform = CGAffineTransform(translationX: 0.0, y: targetSize.height)
            transform = transform.scaledBy(x: 1, y: -1)
            context.cgContext.concatenate(transform)

            if let cgImage = image.cgImage?.cropping(to: cropRect) {
                context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
            } // TODO: CIImage
        }
    }
}

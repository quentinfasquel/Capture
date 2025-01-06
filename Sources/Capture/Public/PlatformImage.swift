//
//  PlatformImage.swift
//  Capture
//
//  Created by Quentin Fasquel on 03/01/2024.
//

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif



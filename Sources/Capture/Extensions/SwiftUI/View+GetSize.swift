//
//  View+GetSize.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/12/2023.
//

import SwiftUI

extension View {
    func getSize(_ binding: Binding<CGSize>) -> some View {
        self.background {
            GeometryReader { geometry in
                Color.clear.hidden().onAppear {
                    binding.wrappedValue = geometry.size
                }.onChange(of: geometry.size) { newSize in
                    binding.wrappedValue = newSize
                }
            }
        }
    }
}

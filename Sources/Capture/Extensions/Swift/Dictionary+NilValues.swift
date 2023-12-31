//
//  Dictionary+NilValues.swift
//  Capture
//
//  Created by Quentin Fasquel on 26/12/2023.
//

import Foundation

extension Dictionary where Value == Optional<Any> {
    func removingNilValues() -> [Key: Any] {
        self.compactMapValues {
            guard let value = $0 else { return nil }
            return value
        }
    }
}

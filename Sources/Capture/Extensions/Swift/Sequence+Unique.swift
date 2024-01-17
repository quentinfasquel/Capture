//
//  Sequence+Unique.swift
//  Capture
//
//  Created by Quentin Fasquel on 17/01/2024.
//

import Foundation

extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

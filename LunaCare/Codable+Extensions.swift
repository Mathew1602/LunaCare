//
//  Codable+Extensions.swift.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-30.
//

import Foundation

extension WeeklyInsight {
    func withDocumentID(_ id: String) -> WeeklyInsight {
        var copy = self
        copy.id = id
        return copy
    }
}



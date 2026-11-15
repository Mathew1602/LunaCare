//
//  PPDRiskTier.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-05.
//

import SwiftUI

enum PPDRiskTier: String, CaseIterable {
    case low, medium, high

    static let mediumThreshold = 0.60
    static let highThreshold = 0.85

    static var mediumPercent: Int { Int((mediumThreshold * 100).rounded()) }
    static var highPercent: Int { Int((highThreshold * 100).rounded()) }

    static func percent(_ score: Double) -> Int {
        Int((score * 100).rounded())
    }

    init(score: Double) {
        let percent = Self.percent(score)
        if percent >= Self.highPercent {
            self = .high
        } else if percent >= Self.mediumPercent {
            self = .medium
        } else {
            self = .low
        }
    }

    var title: String {
        switch self {
        case .low: return "Low risk"
        case .medium: return "Medium risk"
        case .high: return "High risk"
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(red: 0.25, green: 0.61, blue: 0.48)
        case .medium: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .high: return Color(red: 0.93, green: 0.34, blue: 0.34)
        }
    }

    var summary: String {
        switch self {
        case .low:
            return "Your recent patterns look steady. Keep checking in."
        case .medium:
            return "Some patterns are worth watching. Keep logging and mention them at your next check-up."
        case .high:
            return "Your recent patterns stand out. Consider reaching out to your healthcare provider."
        }
    }

    static var rangeDescription: String {
        "Low < \(mediumPercent)% · Medium \(mediumPercent)–\(highPercent - 1)% · High ≥ \(highPercent)%"
    }
}

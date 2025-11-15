//
//  Models.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//  Updated by Xiaoya Zou

import Foundation

enum Mood: String, CaseIterable, Identifiable, Codable {
    case ecstatic = "🤩"
    case happy    = "😊"
    case okay     = "😐"
    case sad      = "😕"
    case angry    = "😠"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ecstatic: return "Ecstatic"
        case .happy:    return "Happy"
        case .okay:     return "Okay"
        case .sad:      return "Sad"
        case .angry:    return "Angry"
        }
    }
}

struct UserProfile: Codable, Identifiable {
    var id: String?             // Firestore doc id
    var email: String?
    var consent: [String: Bool]?
    var createdAt: Date?
    var updatedAt: Date?
}

struct MoodLog: Codable, Identifiable {
    var id: String?
    var mood: Int
    var notes: String?
    var tags: [String]?
    var source: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct Measurement: Codable, Identifiable {
    var id: String?
    var date: String
    var hrRest: Double?
    var steps: Int?
    var sleepMinutes: Int?
    var source: String?
    var updatedAt: Date?
    var createdAt: Date?
}

struct Insight: Codable, Identifiable {
    var id: String?
    var kind: String
    var text: String
    var score: Double
    var inputs: [String: String]?
    var createdAt: Date?
}

struct SymptomRow: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
}

struct SymptomLogPayload: Codable {
    let values: [String: Int]
    let notes: String?
    let tags: [String]?
    let source: String?
}

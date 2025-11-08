//
//  Models.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation



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

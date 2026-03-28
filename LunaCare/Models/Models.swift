//
//  Models.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//  Updated by Xiaoya Zou
//

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
    var id: String?
    var email: String?
    var firstName: String?
    var lastName: String?
    var consent: [String: Bool]?
    var createdAt: Date?
    var updatedAt: Date?
    var noAccount: Bool?

    var fullName: String {
        let f = (firstName ?? "").trimmingCharacters(in: .whitespaces)
        let l = (lastName ?? "").trimmingCharacters(in: .whitespaces)
        let combined = "\(f) \(l)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? (email ?? "") : combined
    }

    enum CodingKeys: String, CodingKey {
        case id, email, firstName, lastName, consent, createdAt, updatedAt
    }
}

struct InsightResult: Codable {
    let last7Avg: Double
    let prev7Avg: Double
    let delta: Double
    let percentChange: Double
    let direction: String
}

struct WeeklyInsight: Identifiable, Codable {
    var id: String?              // Firebase doc ID OR local UUID
    var metric: String           // “sleep hours”
    var text: String             // Full insight text
    var last7Avg: Double
    var prev7Avg: Double
    var delta: Double
    var percentChange: Double
    var direction: String
    var createdAt: Date
    var localOnly: Bool?         // true if only stored locally
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

struct Insight: Codable, Identifiable {
    var id: String?
    var kind: String
    var text: String
    var score: Double
    var inputs: [String: String]?
    var createdAt: Date?
}

struct SymptomRow: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let value: Int
}

struct SymptomLogPayload: Codable {
    let values: [String: Int]
    let notes: String?
    let tags: [String]?
    let source: String?
}

/// One symptom check-in (time + list of SymptomRow)
struct SymptomLogSummary: Codable, Identifiable, Hashable {
    var id = UUID()
    let createdAt: Date
    let rows: [SymptomRow]
}

struct CalendarDayLog: Codable, Identifiable, Hashable {
    /// Firestore doc ID (same as MoodLog.id)
    let id: String
    let mood: Mood
    let note: String?
    let createdAt: Date
}

struct Measurement: Codable, Identifiable {
    var id: String? = nil
    var createdAt: Date = Date()

    // Symptom / mood bases (from logs)
    var mood1to5: Double?
    var bleeding1to10: Double?
    var hairLoss1to10: Double?
    var appetiteIssue1to10: Double?
    var sleepTrouble1to10: Double?
    var fatigue1to10: Double?   // <-- NEW property added

    // Activity / movement bases
    var steps: Int?
    var distanceWalkedKm: Double?
    var flightsClimbed: Double?
    var activeEnergyKcal: Double?
    var basalEnergyKcal: Double?
    var exerciseMinutes: Double?
    var standHours: Double?
    var sunlightHours: Double?

    // Heart / cardio bases
    var avgHeartRateBpm: Double?
    var restingHRBpm: Double?
    var walkingHeartRateAvgBpm: Double?
    var hrvSDNNms: Double?
    var respiratoryRateBpm: Double?
    var oxygenSaturationPct: Double?
    var vo2Max: Double?

    // Sleep bases
    var sleepHours: Double?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var coreSleepHours: Double?
    var sleepEfficiencyPct: Double?
    var wakeAfterSleepOnsetMin: Double?

    var weightKg: Double?

    var source: String? = "watch"
}

extension Measurement {
    var date: String {
        ISO8601DateFormatter().string(from: createdAt)
    }

    var hrRest: Double? {
        restingHRBpm
    }

    var sleepMinutes: Int? {
        sleepHours.map { Int($0 * 60.0) }
    }
}

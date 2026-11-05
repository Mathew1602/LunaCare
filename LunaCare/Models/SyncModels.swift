//
//  SyncModels.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

enum SyncType: String, Codable {
    case moodLog
    case symptomLog
    case measurement
    case insight
    case profile

    case getMoodRequest
    case getMoodResponse

    case getSymptomRequest
    case getSymptomResponse

    case getRiskRequest
    case getRiskResponse
}

struct SyncMessage: Identifiable {
    let id = UUID()
    let type: SyncType

    var moodLog: MoodLog? = nil
    var symptomLog: SymptomLogPayload? = nil
    var measurement: Measurement? = nil 
    var insight: Insight? = nil
    var profile: UserProfile? = nil

    var getMoodRequest: GetRequest? = nil
    var getMoodResponse: [CalendarDayLog]? = nil

    var getSymptomRequest: GetRequest? = nil
    var getSymptomResponse: [SymptomLogSummary]? = nil

    var getRiskResponse: WatchRiskSummary? = nil
}

struct WatchRiskSummary: Codable {
    let score: Double?
    let message: String?
    let computedAt: Date
}

struct GetRequest: Codable {
    let from: Date
    let to: Date
}

/// Used only for offline storage of symptoms.
struct LocalSymptomLog: Codable {
    var id: String?
    let payload: SymptomLogPayload
    let createdAt: Date
    var updatedAt: Date?

    init(id: String? = nil, payload: SymptomLogPayload, createdAt: Date, updatedAt: Date? = nil) {
        self.id = id ?? Self.dayID(for: createdAt)
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func dayID(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

//
//  SyncModels.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

// The type of data being synced
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
}

// Wrapper for incoming sync messages
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
}

struct GetRequest: Codable {
    let from: Date
    let to: Date
}

/// Used only for offline storage of symptoms.
struct LocalSymptomLog: Codable {
    let payload: SymptomLogPayload
    let createdAt: Date
}

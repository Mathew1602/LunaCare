//
//  SyncModels.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation

//The type of data being synced
enum SyncType: String, Codable {
    case moodLog
    case measurement
    case insight
    case profile
}

//Wrapper for incoming sync messages
struct SyncMessage: Identifiable {
    let id = UUID()
    let type: SyncType

    var moodLog: MoodLog?
    var measurement: Measurement?
    var insight: Insight?
    var profile: UserProfile?
}

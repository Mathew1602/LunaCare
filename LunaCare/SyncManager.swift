//
//  SyncManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class SyncManager {
    static let shared = SyncManager()
    private init() {}

    func applyCloudSyncPreference(uid: String, isOn: Bool, env: AppEnvironment) {
        env.isCloudSyncOn = isOn
        UserRepository().setCloudSync(uid: uid, isOn: isOn)
        // In a later iteration, trigger upload/download here if needed.
    }
}

//
//  SyncManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation


final class SyncManager {
    static let shared = SyncManager()
    let userRepository = UserRepository()
    private init() {}

    func applyCloudSyncPreference(uid: String, isOn: Bool, env: AppEnvironment) {
        if uid.isEmpty  {
            return
        }else {
            env.isCloudSyncOn = isOn
            UserDefaults.standard.set(isOn, forKey: "cloudSyncEnabled")
            userRepository.setCloudSync(uid: uid, isOn: isOn)
            // In a later iteration, trigger upload/download here if needed.
        }
    }
    
    func getCloudSyncPreference(uid: String, env: AppEnvironment) async -> Bool {
        if uid.isEmpty {
            return env.isCloudSyncOn
        }
        return await withCheckedContinuation { continuation in
            userRepository.fetchCloudSync(uid: uid) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

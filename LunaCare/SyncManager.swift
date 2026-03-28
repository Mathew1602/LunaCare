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
        env.isCloudSyncOn = isOn
        UserDefaults.standard.set(isOn, forKey: "cloudSyncEnabled")

        // Only write to Firestore when there is a real signed-in user.
        guard !uid.isEmpty else { return }
        userRepository.setCloudSync(uid: uid, isOn: isOn)
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

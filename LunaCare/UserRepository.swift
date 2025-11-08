//
//  UserRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class UserRepository {
    func fetchCloudSync(uid: String, completion: @escaping (Bool) -> Void) {
        FirestoreManager.shared.get(path: FSPath.userMeta(uid)) { data in
            let on = (data?["cloudSync"] as? Bool) ?? false
            completion(on)
        }
    }

    func setCloudSync(uid: String, isOn: Bool) {
        let data: [String: Any] = [
            "cloudSync": isOn,
            "updatedAt": Date()
        ]
        FirestoreManager.shared.write(path: FSPath.userMeta(uid), data: data, merge: true)
    }
}

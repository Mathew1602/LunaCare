//
//  UserRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation

final class UserRepository {

    // MARK: - User profile (name + email)

    func createUserProfile(uid: String,
                           email: String,
                           firstName: String,
                           lastName: String) {
        let now = Date()
        let data: [String: Any] = [
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            // default cloud sync off until user turns it on
            "cloudSync": false,
            "createdAt": now,
            "updatedAt": now
        ]

        FirestoreManager.shared.write(path: FSPath.userMeta(uid),
                                      data: data,
                                      merge: true)
    }

    func fetchUserProfile(uid: String,
                          completion: @escaping (_ firstName: String?, _ lastName: String?) -> Void) {
        FirestoreManager.shared.get(path: FSPath.userMeta(uid)) { data in
            let first = data?["firstName"] as? String
            let last  = data?["lastName"] as? String
            completion(first, last)
        }
    }

    // MARK: - Cloud Sync

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
        FirestoreManager.shared.write(path: FSPath.userMeta(uid),
                                      data: data,
                                      merge: true)
    }
}

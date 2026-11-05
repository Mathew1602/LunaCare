//
//  UserRepository.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseAuth

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
            "cloudSync": false,
            "ppdLabel": ["status": "unverified", "verifiedAt": NSNull(), "verifiedBy": NSNull()],
            "createdAt": now,
            "updatedAt": now
        ]

        FirestoreManager.shared.write(path: FSPath.userMeta(uid),
                                      data: data,
                                      merge: true)
    }

    func fetchUserProfile(uid: String,
                          completion: @escaping (_ firstName: String?, _ lastName: String?) -> Void) {
        FirestoreManager.shared.get(path: FSPath.userMeta(uid)) { data, _ in
            let first = data?["firstName"] as? String
            let last  = data?["lastName"] as? String
            completion(first, last)
        }
    }

    func updateUserProfile(uid: String, firstName: String, lastName: String) async throws {
        let data: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            "updatedAt": Date()
        ]
        try await FirestoreManager.shared.setDocument(path: FSPath.userMeta(uid), data: data)
    }

    // MARK: - Cloud Sync

    func fetchCloudSync(uid: String, completion: @escaping (Bool?) -> Void) {
        FirestoreManager.shared.get(path: FSPath.userMeta(uid)) { data, error in
            guard error == nil else {
                completion(nil)
                return
            }
            completion((data?["cloudSync"] as? Bool) ?? false)
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

    // MARK: - Home Metrics

    func fetchHomeMetrics(uid: String, completion: @escaping ([String]?) -> Void) {
        FirestoreManager.shared.get(path: FSPath.userMeta(uid)) { data, _ in
            completion(data?["homeMetrics"] as? [String])
        }
    }

    func setHomeMetrics(uid: String, metrics: [HealthMetric]) {
        let data: [String: Any] = [
            "homeMetrics": metrics.map(\.rawValue),
            "updatedAt": Date()
        ]
        FirestoreManager.shared.write(path: FSPath.userMeta(uid),
                                      data: data,
                                      merge: true)
    }

    func resetPassword(email: String,
                      currentPassword: String,
                      newPassword: String,
                      completion: @escaping (Error?) -> Void) {
        
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty, !currentPassword.isEmpty, !newPassword.isEmpty else {
            let error = NSError(domain: "UserRepository",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "All fields are required."])
            completion(error)
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            let error = NSError(domain: "UserRepository",
                              code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "No authenticated user found."])
            completion(error)
            return
        }

        guard let userEmail = currentUser.email, userEmail.lowercased() == email.lowercased() else {
            let error = NSError(domain: "UserRepository",
                              code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Email does not match your account."])
            completion(error)
            return
        }

        let credential = EmailAuthProvider.credential(withEmail: userEmail, password: currentPassword)
        
        currentUser.reauthenticate(with: credential) { _, authError in
            if let authError = authError {
                let code = AuthErrorCode(rawValue: (authError as NSError).code)
                if code == .wrongPassword || code == .invalidCredential {
                    let error = NSError(domain: "UserRepository",
                                      code: -4,
                                      userInfo: [NSLocalizedDescriptionKey: "Incorrect password. Please try again."])
                    completion(error)
                } else {
                    completion(authError)
                }
                return
            }

            currentUser.updatePassword(to: newPassword) { updateError in
                completion(updateError)
            }
        }
    }
    
    func sendPasswordResetEmail(email: String,
                              completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("Password reset email error: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Password reset email sent to: \(email)")
                completion(nil)
            }
        }
    }
    
}

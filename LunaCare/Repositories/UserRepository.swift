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
    
    /// Updates user profile information (first name and last name)
    func updateUserProfile(uid: String,
                          firstName: String,
                          lastName: String,
                          completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            "updatedAt": Date()
        ]
        
        FirestoreManager.shared.write(path: FSPath.userMeta(uid),
                                      data: data,
                                      merge: true)
        
        // Refresh the profile after saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fetchUserProfile(uid: uid) { _, _ in
                completion(nil)
            }
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
    
    func resetPassword(email: String,
                      currentPassword: String,
                      newPassword: String,
                      completion: @escaping (Error?) -> Void) {
        
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPassword = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        
        // Verify the email matches the current user's email
        guard let userEmail = currentUser.email, userEmail.lowercased() == email.lowercased() else {
            let error = NSError(domain: "UserRepository",
                              code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Email does not match your account."])
            completion(error)
            return
        }
        
        // Reauthenticate with current password
        let credential = EmailAuthProvider.credential(withEmail: userEmail, password: currentPassword)
        
        currentUser.reauthenticate(with: credential) { _, authError in
            if let authError = authError {
                let nsError = authError as NSError
                
                // Handle specific Firebase errors
                if nsError.code == AuthErrorCode.wrongPassword.rawValue {
                    let error = NSError(domain: "UserRepository",
                                      code: -4,
                                      userInfo: [NSLocalizedDescriptionKey: "Incorrect password. Please try again."])
                    completion(error)
                } else {
                    completion(authError)
                }
                return
            }
            
            // Now update the password
            currentUser.updatePassword(to: newPassword) { updateError in
                if let updateError = updateError {
                    completion(updateError)
                } else {
                    completion(nil)
                }
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

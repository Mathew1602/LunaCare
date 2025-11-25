//
//  AuthViewModel.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseAuth

final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var email: String = ""
    @Published var uid: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var errorMessage: String = ""

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if !firstName.trimmingCharacters(in: .whitespaces).isEmpty { return firstName }
        return email
    }

    /// In the real app you call `AuthViewModel()` (default: listens to Firebase).
    /// In previews you'll use `AuthViewModel(listenToAuth: false)` via `AuthViewModel.preview`.
    init(listenToAuth: Bool = true) {
        guard listenToAuth else { return }

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            self.isAuthenticated = (user != nil)
            self.email = user?.email ?? ""
            self.uid = user?.uid ?? ""

            guard let uid = user?.uid else {
                self.firstName = ""
                self.lastName = ""
                return
            }

            // Load profile (first + last name) from Firestore
            UserRepository().fetchUserProfile(uid: uid) { first, last in
                DispatchQueue.main.async {
                    self.firstName = first ?? ""
                    self.lastName = last ?? ""
                    self.sendProfileToWatch()
                }
            }
        }
    }

    func signIn(email rawEmail: String, password rawPassword: String) {
        errorMessage = ""
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = rawPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = self.message(for: error)
            }
            // auth state listener will update flags & load profile
        }
    }

    func signUp(email rawEmail: String,
                password rawPassword: String,
                firstName: String,
                lastName: String) {
        errorMessage = ""
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = rawPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = self.message(for: error)
                return
            }

            guard let user = result?.user else { return }

            self.uid = user.uid
            self.email = email
            self.firstName = firstName
            self.lastName = lastName

            // Save profile to Firestore
            UserRepository().createUserProfile(uid: user.uid,
                                               email: email,
                                               firstName: firstName,
                                               lastName: lastName)
            self.sendProfileToWatch()
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = ""
            firstName = ""
            lastName = ""
            email = ""
            uid = ""
            
            let emptyProfile = UserProfile(id: nil, email: nil, firstName: nil, lastName: nil)
                    WatchConnectivityManager.shared.send(emptyProfile, type: .profile)
        } catch {
            errorMessage = "Could not sign out. Try again."
        }
    }

    private func message(for error: Error) -> String {
        let ns = error as NSError
        guard let code = AuthErrorCode(rawValue: ns.code) else {
            print("Auth error \(ns.code): \(ns.localizedDescription) – \(ns.userInfo)")
            return "Unexpected error. Please try again."
        }
        print("Auth error \(code.rawValue): \(ns.localizedDescription) – \(ns.userInfo)")

        switch code {
        case .userNotFound:      return "No account found for this email. Please register."
        case .wrongPassword:     return "Incorrect password. Please try again."
        case .invalidEmail:      return "That email address looks invalid."
        case .emailAlreadyInUse: return "An account already exists for this email."
        case .weakPassword:      return "Please choose a stronger password."
        case .invalidCredential: return "Login method mismatch. Use email + password here."
        default:                 return ns.localizedDescription
        }
    }
    
    private func sendProfileToWatch() {
        guard !uid.isEmpty else { return }

        let profile = UserProfile(
            id: uid,
            email: email,
            firstName: firstName,
            lastName: lastName,
            consent: nil,
            createdAt: nil,
            updatedAt: nil
        )

        WatchConnectivityManager.shared.send(profile, type: .profile)
        print("Sent profile to watch: \(profile.fullName)")
    }

}

// MARK: - Preview helper
extension AuthViewModel {
    /// Static instance used only for SwiftUI previews.
    static var preview: AuthViewModel {
        let vm = AuthViewModel(listenToAuth: false)
        vm.isAuthenticated = true
        vm.email = "preview@example.com"
        vm.uid = "preview-uid"
        vm.firstName = "Preview"
        vm.lastName = "User"
        return vm
    }
}



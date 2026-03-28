//
//  AuthViewModel.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseAuth

private enum GuestKeys {
    static let firstName = "lunacare.guest.firstName"
    static let lastName  = "lunacare.guest.lastName"
    static let noAccount = "lunacare.guest.noAccount"
}

final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var noAccount: Bool = false          // true = guest / local-only mode
    @Published var email: String = ""
    @Published var uid: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var errorMessage: String = ""
    @Published var didResolveAuthState: Bool = false

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if !firstName.trimmingCharacters(in: .whitespaces).isEmpty { return firstName }
        return email
    }

    init(listenToAuth: Bool = true) {
        guard listenToAuth else { return }

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            if let user = user {
                // ── Authenticated via Firebase ──────────────────────────────
                self.isAuthenticated = true
                self.noAccount = false
                self.email = user.email ?? ""
                self.uid  = user.uid

                UserRepository().fetchUserProfile(uid: user.uid) { first, last in
                    DispatchQueue.main.async {
                        self.firstName = first ?? ""
                        self.lastName  = last  ?? ""
                        self.sendProfileToWatch()
                        self.didResolveAuthState = true
                    }
                }

            } else {
                // ── Not signed into Firebase — check for guest session ──────
                self.isAuthenticated = false
                self.email = ""
                self.uid   = ""

                let isGuest = UserDefaults.standard.bool(forKey: GuestKeys.noAccount)
                if isGuest {
                    self.noAccount  = true
                    self.firstName  = UserDefaults.standard.string(forKey: GuestKeys.firstName) ?? ""
                    self.lastName   = UserDefaults.standard.string(forKey: GuestKeys.lastName)  ?? ""
                } else {
                    self.noAccount = false
                    self.firstName = ""
                    self.lastName  = ""
                }

                self.didResolveAuthState = true
            }
        }
    }

    // MARK: - Firebase Auth

    func signIn(email rawEmail: String, password rawPassword: String) {
        errorMessage = ""
        let email    = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }
    }

    func signUp(email rawEmail: String,
                password rawPassword: String,
                firstName: String,
                lastName: String) {
        errorMessage = ""
        let email    = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
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

            // Clear any stale guest session data from UserDefaults (no-op if not a guest).
            UserDefaults.standard.removeObject(forKey: GuestKeys.firstName)
            UserDefaults.standard.removeObject(forKey: GuestKeys.lastName)
            UserDefaults.standard.set(false, forKey: GuestKeys.noAccount)

            self.uid       = user.uid
            self.email     = email
            self.firstName = firstName
            self.lastName  = lastName

            UserRepository().createUserProfile(uid: user.uid,
                                               email: email,
                                               firstName: firstName,
                                               lastName: lastName)
            self.sendProfileToWatch()
        }
    }

    func signOut() {
        // ── Guest sign-out: wipe local data ─────────────────────────────────
        if noAccount {
            clearGuestSession()
            return
        }

        // ── Firebase sign-out ────────────────────────────────────────────────
        do {
            try Auth.auth().signOut()
            errorMessage = ""
            firstName    = ""
            lastName     = ""
            email        = ""
            uid          = ""

            let emptyProfile = UserProfile(id: nil, email: nil, firstName: nil, lastName: nil)
            WatchConnectivityManager.shared.send(emptyProfile, type: .profile)
        } catch {
            errorMessage = "Could not sign out. Try again."
        }
    }

    // MARK: - Guest / Local-only session

    /// Saves first + last name to UserDefaults and enters local-only mode.
    func signInAsGuest(firstName: String, lastName: String) {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(first, forKey: GuestKeys.firstName)
        UserDefaults.standard.set(last,  forKey: GuestKeys.lastName)
        UserDefaults.standard.set(true,  forKey: GuestKeys.noAccount)

        DispatchQueue.main.async {
            self.firstName  = first
            self.lastName   = last
            self.noAccount  = true
            self.errorMessage = ""
        }
    }

    private func clearGuestSession() {
        UserDefaults.standard.removeObject(forKey: GuestKeys.firstName)
        UserDefaults.standard.removeObject(forKey: GuestKeys.lastName)
        UserDefaults.standard.set(false, forKey: GuestKeys.noAccount)

        DispatchQueue.main.async {
            self.noAccount  = false
            self.firstName  = ""
            self.lastName   = ""
            self.errorMessage = ""
        }
    }

    // MARK: - Helpers

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

    func refreshProfile() {
        guard !uid.isEmpty else { return }
        UserRepository().fetchUserProfile(uid: uid) { first, last in
            DispatchQueue.main.async {
                self.firstName = first ?? ""
                self.lastName  = last  ?? ""
                self.sendProfileToWatch()
            }
        }
    }
}

// MARK: - Preview helper
extension AuthViewModel {
    static var preview: AuthViewModel {
        let vm = AuthViewModel(listenToAuth: false)
        vm.isAuthenticated = true
        vm.email     = "preview@example.com"
        vm.uid       = "preview-uid"
        vm.firstName = "Preview"
        vm.lastName  = "User"
        return vm
    }

    static var previewGuest: AuthViewModel {
        let vm = AuthViewModel(listenToAuth: false)
        vm.noAccount = true
        vm.firstName = "Guest"
        vm.lastName  = "User"
        return vm
    }
}

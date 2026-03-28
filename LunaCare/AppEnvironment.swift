//
//  AppEnvironment.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

//
//  AppEnvironment.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import Foundation
import FirebaseAuth

final class AppEnvironment: ObservableObject {

    static let shared = AppEnvironment()

    @Published var isCloudSyncOn: Bool = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
        }
    }
    @Published var insightsRepo: InsightsRepository?

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme")
        self.selectedTheme = AppTheme(rawValue: savedTheme ?? "") ?? .system
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            if let user = user {
                print("Firebase user active. UID: \(user.uid)")
                self.configureRepositories(uid: user.uid)

                // Immediately load the user's saved cloud-sync preference so
                // all components (including WatchSyncService) use the correct
                // value without waiting for SettingsView to appear.
                UserRepository().fetchCloudSync(uid: user.uid) { cloudOn in
                    DispatchQueue.main.async {
                        self.isCloudSyncOn = cloudOn
                        UserDefaults.standard.set(cloudOn, forKey: "cloudSyncEnabled")
                    }
                }
            } else {
                print("Firebase user signed out")
                self.insightsRepo = nil

                // Reset to local-only so a subsequent guest session doesn't
                // inherit a stale cloud-sync preference.
                DispatchQueue.main.async {
                    self.isCloudSyncOn = false
                    UserDefaults.standard.set(false, forKey: "cloudSyncEnabled")
                }
            }
        }
    }

    private func configureRepositories(uid: String) {
        print("Configuring Repositories for UID: \(uid)")
        self.insightsRepo = InsightsRepository(uid: uid)
        print("insightsRepo created =", self.insightsRepo != nil)
    }
}

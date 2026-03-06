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

    @Published var isCloudSyncOn: Bool = false
    @Published var insightsRepo: InsightsRepository?

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            if let user = user {
                print("Firebase user active. UID: \(user.uid)")
                self.configureRepositories(uid: user.uid)
            } else {
                print(" Firebase user signed out")
                self.insightsRepo = nil
            }
        }
    }

    private func configureRepositories(uid: String) {
        print("Configuring Repositories for UID: \(uid)")
        self.insightsRepo = InsightsRepository(uid: uid)
        print("insightsRepo created =", self.insightsRepo != nil)
    }
}

//
//  LunaCareApp.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-09-11.
//  Updated by Fernanda

import SwiftUI
import Firebase

@main
struct LunaCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var env  = AppEnvironment.shared
    @StateObject private var auth = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // This activates connectivity to watchOS
        WatchConnectivityManager.shared.activate()
        _ = WatchSyncService.shared

        #if DEBUG
        Task.detached(priority: .background) { PPDParityCheck.run() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(env)
                .environmentObject(auth)
                .preferredColorScheme(env.selectedTheme.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { runModelSync() }
                }
                .onChange(of: auth.uid) { _, uid in
                    if !uid.isEmpty { runModelSync() }
                }
        }
    }

    private func runModelSync() {
        Task {
            await ModelUpdateService.shared.checkForUpdate()
            await FLContributionService.shared.uploadIfDue()
        }
    }
}

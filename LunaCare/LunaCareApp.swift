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

    init() {
        // This activates connectivity to watchOS
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(env)
                .environmentObject(auth)
                .preferredColorScheme(env.selectedTheme.colorScheme)
                .onAppear {
                    WatchSyncService.shared.configure(uidProvider: { auth.uid }, env: env)
                }
        }
    }
}


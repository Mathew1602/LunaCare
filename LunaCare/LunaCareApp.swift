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
        //REQUIRED: activate connectivity with watch to send data back and forth
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(env)
                .environmentObject(auth)
        }
    }
}

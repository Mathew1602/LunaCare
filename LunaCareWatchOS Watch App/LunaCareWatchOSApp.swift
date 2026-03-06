//
//  LunaCareWatchOSApp.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

@main
struct LunaCareWatchOS_Watch_AppApp: App {
    @StateObject private var health = AppleWatchDataStore.shared

    init() {
        //REQUIRED: activate connectivity with IOS application
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(health)
                .task { await health.authorizeAndRefresh() }
        }
    }
}

    


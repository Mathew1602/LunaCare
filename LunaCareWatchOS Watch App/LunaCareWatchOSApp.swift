//
//  LunaCareWatchOSApp.swift
//  LunaCareWatchOS Watch App
//
//  Created by Mathew Boyd on 2025-10-23.
//

import SwiftUI

@main
struct LunaCareWatchOS_Watch_AppApp: App {

    init() {
        //REQUIRED: activate connectivity with IOS application
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


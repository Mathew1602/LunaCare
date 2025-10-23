//
//  LunaCareApp.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-09-11.
//

import SwiftUI
import UserNotifications

@main
struct LunaCareApp: App {
    
    init() {
        // set delegate + ask for permission once on launch
        NotificationManager.shared.center.delegate = NotificationManager.shared
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            //ContentView()
            //HomeView()
            LoginView()
        }
    }
}

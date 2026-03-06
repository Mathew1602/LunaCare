//
//  AppDelegate.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import UIKit
import Firebase
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured (AppDelegate)")
        }
        
        //Notifcation permissions
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.requestAuthorization()
        
        
        // Use App Check debug provider only if the module exists and we're in DEBUG.
        #if DEBUG
        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        print("🧪 AppCheck in DEBUG mode (debug provider)")
        #else
        print("FirebaseAppCheck not linked; skipping App Check setup")
        #endif
        #endif

        return true
    }
}

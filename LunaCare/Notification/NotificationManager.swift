//
//  NotificationManager.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-23.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    let center = UNUserNotificationCenter.current()

    // Ask user for permission
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            if let err = err { print("Notification authorization error:", err) }
            print("Notifications granted:", granted)
        }
    }

    // Show banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Schedule a one-off demo notification
    func scheduleDemo(after seconds: TimeInterval) {
        // avoid piling up multiple pending requests
        center.removePendingNotificationRequests(withIdentifiers: ["demo.mood.reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to log your mood :)"
        content.body  = "A quick check-in helps track your well-being."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let req = UNNotificationRequest(identifier: "demo.mood.reminder",
                                        content: content,
                                        trigger: trigger)
        center.add(req)
    }
}


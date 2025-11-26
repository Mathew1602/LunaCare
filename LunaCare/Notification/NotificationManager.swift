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
    
    func scheduleHealthAlertsIfNeeded(from alerts: [WeeklyInsight]) {
        // No alerts → nothing to schedule
        guard !alerts.isEmpty else { return }

        let center = UNUserNotificationCenter.current()

       

        let content = UNMutableNotificationContent()
        content.title = "LunaCare Health Alert"

        if alerts.count == 1 {
            // Use the full insight text for a single alert
            content.body = alerts[0].text
        } else {
            let names = alerts.prefix(2).map { $0.metric }
            let joined = names.joined(separator: " & ")
            content.body = "Changes detected in \(joined). Open LunaCare to view your health alerts."
        }

        content.sound = .default

        // Fire shortly after insights load (3 seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)

        let request = UNNotificationRequest(
            identifier: "health-alert-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request, withCompletionHandler: nil)
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


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

    static let dailyReminderID = "daily.checkin.reminder"
    private let lastPPDAlertKey = "notif.ppdAlerts.lastDate"

    // Ask user for permission
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            if let err = err { print("Notification authorization error:", err) }
            print("Notifications granted:", granted)
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification authorization error:", error)
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func updateDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])
        guard NotificationPreferences.dailyReminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for your LunaCare check-in"
        content.body = "Take a moment to log your mood and how you’re feeling today."
        content.sound = .default

        var time = DateComponents()
        time.hour = NotificationPreferences.dailyReminderHour
        time.minute = NotificationPreferences.dailyReminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        let request = UNNotificationRequest(identifier: Self.dailyReminderID,
                                            content: content,
                                            trigger: trigger)
        center.add(request) { error in
            if let error { print("Failed to schedule daily reminder:", error) }
        }
    }

    func schedulePPDHighRiskAlertIfNeeded(score: Double) {
        guard NotificationPreferences.ppdAlertsEnabled,
              PPDRiskTier(score: score) == .high else { return }

        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastPPDAlertKey) as? Date,
           Calendar.current.isDateInToday(last) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "LunaCare check-in"
        content.body = "Some of your recent patterns stand out. Open LunaCare to see your alerts, and consider reaching out to your healthcare provider."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "ppd-high-risk-\(UUID().uuidString)",
                                            content: content,
                                            trigger: trigger)
        center.add(request) { [lastPPDAlertKey] error in
            if let error {
                print("Failed to schedule PPD alert:", error)
            } else {
                UserDefaults.standard.set(Date(), forKey: lastPPDAlertKey)
            }
        }
    }

    func scheduleHealthAlertsIfNeeded(from alerts: [WeeklyInsight]) {
        guard NotificationPreferences.trendAlertsEnabled else { return }
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

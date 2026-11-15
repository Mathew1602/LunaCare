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
    static let ppdAlertID = "ppd-high-risk"
    private let lastPPDAlertKey = "notif.ppdAlerts.lastDate"

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            if let err = err { print("Notification authorization error:", err) }
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

        let previous = StorageScope.object(forKey: lastPPDAlertKey) as? Date
        if let previous, Calendar.current.isDateInToday(previous) { return }
        StorageScope.set(Date(), forKey: lastPPDAlertKey)

        let content = UNMutableNotificationContent()
        content.title = "LunaCare check-in"
        content.body = "Some of your recent patterns stand out. Open LunaCare to see your alerts, and consider reaching out to your healthcare provider."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: Self.ppdAlertID,
                                            content: content,
                                            trigger: trigger)
        let key = lastPPDAlertKey
        center.add(request) { error in
            guard let error else { return }
            print("Failed to schedule PPD alert:", error)
            DispatchQueue.main.async {
                StorageScope.set(previous, forKey: key)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

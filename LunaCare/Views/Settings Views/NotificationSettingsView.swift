//
//  NotificationSettingsView.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-05.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(NotificationPreferences.dailyReminderEnabledKey) private var dailyReminderEnabled = false
    @AppStorage(NotificationPreferences.dailyReminderHourKey) private var reminderHour = NotificationPreferences.defaultReminderHour
    @AppStorage(NotificationPreferences.dailyReminderMinuteKey) private var reminderMinute = NotificationPreferences.defaultReminderMinute
    @AppStorage(NotificationPreferences.trendAlertsEnabledKey) private var trendAlertsEnabled = true
    @AppStorage(NotificationPreferences.ppdAlertsEnabledKey) private var ppdAlertsEnabled = true

    @State private var status: UNAuthorizationStatus = .notDetermined

    private var isAllowed: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? NotificationPreferences.defaultReminderHour
                reminderMinute = parts.minute ?? NotificationPreferences.defaultReminderMinute
                NotificationManager.shared.updateDailyReminder()
            }
        )
    }

    private func gated(_ value: Binding<Bool>, onChange: (() -> Void)? = nil) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue && isAllowed },
            set: { newValue in
                value.wrappedValue = newValue
                onChange?()
            }
        )
    }

    var body: some View {
        List {
            permissionSection

            Section {
                Toggle("Daily reminder", isOn: gated($dailyReminderEnabled) {
                    NotificationManager.shared.updateDailyReminder()
                })
                if dailyReminderEnabled && isAllowed {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Daily Check-in")
            } footer: {
                Text("A gentle reminder to log your mood and symptoms each day.")
            }
            .disabled(!isAllowed)

            Section {
                Toggle("Weekly trend red flags", isOn: gated($trendAlertsEnabled))
                Toggle("High PPD risk tier", isOn: gated($ppdAlertsEnabled))
            } header: {
                Text("Health Alerts")
            } footer: {
                Text("Alerts still appear on the Alerts screen in the app. These switches only control notifications.")
            }
            .disabled(!isAllowed)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshStatus() }
            }
        }
    }

    private var permissionSection: some View {
        Section {
            HStack {
                Text("Status")
                Spacer()
                Label(statusText, systemImage: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.subheadline.weight(.semibold))
            }

            switch status {
            case .notDetermined:
                Button("Allow Notifications") {
                    Task {
                        _ = await NotificationManager.shared.requestAuthorization()
                        await refreshStatus()
                    }
                }
            case .denied:
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            default:
                EmptyView()
            }
        } header: {
            Text("Permission")
        } footer: {
            if !isAllowed {
                Text("Allow notifications to turn on reminders and alerts.")
            }
        }
    }

    private var statusText: String {
        switch status {
        case .notDetermined: return "Not asked yet"
        case .denied: return "Not allowed"
        default: return "Allowed"
        }
    }

    private var statusIcon: String {
        switch status {
        case .notDetermined: return "questionmark.circle"
        case .denied: return "xmark.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .notDetermined: return .secondary
        case .denied: return .orange
        default: return .green
        }
    }

    private func refreshStatus() async {
        status = await NotificationManager.shared.authorizationStatus()
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

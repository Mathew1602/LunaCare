
//
//  RecommendationsView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var vm: InsightsViewModel

    @AppStorage(NotificationPreferences.dailyReminderEnabledKey) private var sendDailyReminders = false
    @State private var notificationsDenied = false
    @State private var showPermissionAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if vm.isLoading {
                    ProgressView("Building recommendations…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if vm.recommendations.isEmpty {
                    emptyState
                } else {
                    recommendationSummary

                    let trendRecommendations = vm.recommendations.filter { !$0.isScreening }
                    let screeningRecommendations = vm.recommendations.filter(\.isScreening)

                    LazyVStack(alignment: .leading, spacing: 18) {
                        if !trendRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(trendRecommendations) { item in
                                    RecommendationCard(item: item)
                                }
                            }
                        }

                        if !screeningRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                recommendationSectionTitle(
                                    "Screening support",
                                    subtitle: "The raw model score is supplemental, not a diagnosis or verified confidence."
                                )
                                ForEach(screeningRecommendations) { item in
                                    RecommendationCard(item: item)
                                }
                            }
                        }
                    }
                }

                remindersSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            notificationsDenied = await NotificationManager.shared.authorizationStatus() == .denied
            await vm.loadIfNeeded()
        }
        .alert("Notifications are off", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow notifications for LunaCare in iOS Settings to get daily reminders.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("A few supportive ideas based on your recent health and check-in trends.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.purple)
                    .frame(width: 48, height: 48)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var recommendationSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: 46, height: 46)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 3) {
                    Text("A few ideas for this week")
                        .font(.headline)
                    Text("Based on your recent Insights—not a fixed checklist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purple.opacity(0.12), lineWidth: 1)
        }
    }

    private func recommendationSectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.purple)
                .frame(width: 66, height: 66)
                .background(Color.purple.opacity(0.1), in: Circle())

            VStack(spacing: 7) {
                Text(vm.insights.isEmpty ? "Ideas grow with your check-ins" : "No specific nudge right now")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(vm.insights.isEmpty
                     ? "Keep syncing Apple Health and logging mood or symptoms. We’ll suggest something when your Insights show a useful change."
                     : "Your recent Insights don’t show a change that calls for a specific suggestion. Keep checking in, and we’ll share an idea when a trend gives us something useful.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.purple.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [6]))
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .foregroundColor(.purple)
                Text("Daily routine")
                    .font(.headline)
            }

            Toggle(isOn: Binding(
                get: { sendDailyReminders && !notificationsDenied },
                set: { newValue in Task { await setDailyReminder(newValue) } }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Send daily reminders")
                        .font(.subheadline.weight(.semibold))
                    Text("A gentle nudge to log your mood each day.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.purple)
        }
        .padding(17)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func setDailyReminder(_ isOn: Bool) async {
        let manager = NotificationManager.shared
        if isOn {
            var status = await manager.authorizationStatus()
            if status == .notDetermined {
                _ = await manager.requestAuthorization()
                status = await manager.authorizationStatus()
            }
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                notificationsDenied = true
                showPermissionAlert = true
                return
            }
            notificationsDenied = false
        }
        sendDailyReminders = isOn
        manager.updateDailyReminder()
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let item: RecommendationEngine.RecommendationItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.isScreening
                     ? "SCREENING SIGNAL"
                     : "FROM YOUR INSIGHTS")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 3)
                Text(item.reason)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        }
    }

    private var symbol: String {
        switch item.kind {
        case .sleep: return "moon.zzz.fill"
        case .movement: return "figure.walk"
        case .mood, .screeningSupport: return "heart"
        case .screeningMonitor: return "eye"
        case .symptom: return "cross.case"
        case .vitals: return "heart.text.square"
        case .other: return "sparkles"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .sleep: return Color(red: 0.48, green: 0.40, blue: 0.78)
        case .movement: return Color(red: 0.25, green: 0.61, blue: 0.48)
        case .mood, .screeningSupport: return Color(red: 0.78, green: 0.48, blue: 0.38)
        case .screeningMonitor: return PPDRiskTier.medium.color
        case .symptom, .vitals: return Color(red: 0.78, green: 0.40, blue: 0.48)
        case .other: return .purple
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        RecommendationsView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppEnvironment.shared)
        .environmentObject(InsightsViewModel(auth: AuthViewModel(),
                                             env: AppEnvironment.shared))
    }
}


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

    @State private var insights: [WeeklyInsight] = []
    @State private var recs: [RecommendationEngine.RecommendationItem] = []
    @State private var sendDailyReminders = true

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(recs) { item in
                        RecommendationCard(item: item)
                    }
                }
                .padding(.horizontal, 4)

                remindersSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            insights = vm.insights
            recs = RecommendationEngine.build(from: insights)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Personalized Recommendations")
                .font(.system(.title, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text("Tailored to improve sleep, mood, stress, and energy based on your weekly trends.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Reminders section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $sendDailyReminders) {
                Text("Send daily reminders")
                    .font(.system(size: 16, weight: .semibold))
            }

            Button {
                print("Mark as done pressed")
            } label: {
                Text("Mark as done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sendDailyReminders ? .white : Color(.systemIndigo))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(sendDailyReminders ? Color(.systemIndigo) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(.systemIndigo), lineWidth: sendDailyReminders ? 0 : 2)
                            )
                    )
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Recommendation Card
private struct RecommendationCard: View {
    let item: RecommendationEngine.RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(item.subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 4)

            Text(item.reason)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
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

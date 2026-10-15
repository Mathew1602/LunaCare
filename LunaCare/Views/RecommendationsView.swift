
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

    @State private var sendDailyReminders = true

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
                    LazyVStack(spacing: 14) {
                        ForEach(vm.recommendations) { item in
                            RecommendationCard(item: item)
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
            if vm.insights.isEmpty {
                await vm.loadInsights()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Small, supportive steps shaped by your trends.")
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

            Label("Based on your weekly health data", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var recommendationSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text("A few ideas for this week")
                    .font(.subheadline.weight(.semibold))
                Text("Choose what feels useful for you.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(vm.recommendations.count)")
                .font(.headline.weight(.bold))
                .foregroundColor(.purple)
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purple.opacity(0.14), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.purple)
                .frame(width: 66, height: 66)
                .background(Color.purple.opacity(0.1), in: Circle())

            VStack(spacing: 7) {
                Text("Recommendations grow with your data")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Keep syncing Apple Health and logging mood or symptoms. We’ll share trend-based ideas when there’s enough data to compare two weeks.")
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

    // MARK: - Reminders section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .foregroundColor(.purple)
                Text("Daily routine")
                    .font(.headline)
            }

            Toggle(isOn: $sendDailyReminders) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Send daily reminders")
                        .font(.subheadline.weight(.semibold))
                    Text("A gentle nudge to revisit your goals.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.purple)

            Divider()

            Button {
                print("Mark as done pressed")
            } label: {
                Label("Mark as done", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
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

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text(item.reason)
                    .font(.footnote)
                    .foregroundColor(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: tint.opacity(0.08), radius: 10, y: 4)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 15)
        }
    }

    private var symbol: String {
        switch item.title {
        case "Sleep Routine": return "moon.zzz.fill"
        case "Wind-Down Breathing": return "wind"
        case "Relaxed Movement", "Daily Movement": return "figure.walk"
        case "Mood Check-In": return "face.smiling"
        case "Symptom Check-In": return "cross.case"
        case "Hydration": return "drop.fill"
        default: return "sparkles"
        }
    }

    private var tint: Color {
        switch item.title {
        case "Sleep Routine", "Wind-Down Breathing": return Color(red: 0.48, green: 0.40, blue: 0.78)
        case "Relaxed Movement", "Daily Movement": return Color(red: 0.25, green: 0.61, blue: 0.48)
        case "Mood Check-In": return Color(red: 0.80, green: 0.56, blue: 0.31)
        case "Symptom Check-In": return Color(red: 0.78, green: 0.48, blue: 0.38)
        case "Hydration": return Color(red: 0.30, green: 0.58, blue: 0.78)
        default: return .purple
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

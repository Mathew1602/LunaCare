
//
//  RecommendationsView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//

import SwiftUI


private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)   // #BCAEF2
    static let lcLavenderSoft  = Color(red: 0.95, green: 0.95, blue: 0.98)   // ~#F7F7FB
    static let lcCardShadow    = Color.black.opacity(0.08)
}



struct RecommendationsView: View {
    @State private var sendDailyReminders = true

    private let items: [RecItem] = [
        .init(title: "Breathing", subtitle: "Try a 5-minute breathing session\n(morning & evening)."),
        .init(title: "Sleep Routine", subtitle: "Maintain bedtime 10–11 PM.\nImproves recovery and mood."),
        .init(title: "Hydration", subtitle: "Increase to ~2.5 L/day.\nSet a water reminder every 2 hours."),
        .init(title: "Walking", subtitle: "Add a 10-minute walk after lunch.\nBoosts afternoon energy.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    Text("Personalized Recommendations")
                        .font(.system(.title, design: .rounded).bold())
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)

                    Text("Tailored to improve mood, stress, and energy.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                // Grid 2x2
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(items) { item in
                        RecCard(item: item)
                    }
                }

                // Controls
                Toggle(isOn: $sendDailyReminders) {
                    Text("Send daily reminders")
                }
                .padding(.top, 4)

                SecondaryButton(title: "Mark as done") {
                    // mark done action placeholder
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}



private struct RecCard: View {
    let item: RecItem

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.lcLavenderSoft)
            .shadow(color: .lcCardShadow, radius: 10, y: 6)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .frame(height: 120)
    }
}

private struct SecondaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.lcLavender)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.lcLavender, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)
                )
                .shadow(color: Color.lcCardShadow, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}


private struct RecItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}


#Preview {
    NavigationStack { RecommendationsView() }
}

//
//  InsightsDetailView.swift
//  LunaCare
//
//  Restored & updated by Fernanda Battig on 2025-11-07
//


import SwiftUI

// MARK: - Palette
private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)
    static let lcLavenderSoft  = Color(red: 0.95, green: 0.95, blue: 0.98)
    static let lcCardShadow    = Color.black.opacity(0.08)
}

// MARK: - Screen

struct InsightsDetailView: View {
    @State private var insights: [WeeklyInsight] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                header

                // Metric cards
                VStack(spacing: 16) {
                    ForEach(insights) { item in
                        InsightDetailCard(insight: item)
                    }
                }

                // Spacer + Recommendations button
                VStack(spacing: 12) {
                    NavigationLink {
                        RecommendationsView()
                    } label: {
                        Text("View Recommendations")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.lcLavender)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.lcCardShadow, radius: 12, y: 6)
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load the same insights generated for the overview
            insights = LocalStorageInsights.shared.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly Insight Breakdown")
                .font(.system(.title, design: .rounded).bold())

            Text("Detailed 14-day trend analysis for each metric using AI Insights.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Metric Card

private struct InsightDetailCard: View {
    let insight: WeeklyInsight

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.lcLavenderSoft)
                .shadow(color: .lcCardShadow, radius: 10, y: 6)

            VStack(alignment: .leading, spacing: 10) {

                // Title
                Text(insight.metric)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                // Averages row
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Week Avg: \(formatted(insight.last7Avg))")
                    Text("Previous Week Avg: \(formatted(insight.prev7Avg))")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)

                // Change + direction row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Change: \(formatted(insight.delta)) (\(formattedPercent(insight.percentChange)))")
                        Text("Direction: \(insight.direction.capitalized)")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: arrowIcon)
                        .font(.system(size: 18, weight: .semibold))
                }

                // Text insight
                Text(insight.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var arrowIcon: String {
        switch insight.direction.lowercased() {
        case "higher": return "arrow.up"
        case "lower":  return "arrow.down"
        default:       return "arrow.left.and.right"
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InsightsDetailView()
    }
}

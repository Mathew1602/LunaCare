//
//  InsightsOverviewView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-10-19.
//

import SwiftUI

// MARK: - Palette (kept local so file is standalone)
private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)    // #BCAEF2
    static let lcLavenderSoft  = Color(red: 0.95, green: 0.95, blue: 0.98)    // ~#F7F7FB
    static let lcCardShadow    = Color.black.opacity(0.08)
}

// MARK: - Screen

struct InsightsOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    Text("Your Health Insights")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)

                    Text("AI-powered insights from your mood, sleep, and activity data.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                // Cards
                VStack(spacing: 20) {
                    InsightCard(
                        title: "Stress Level Prediction",
                        subtitle: "You’ve maintained a healthy stress level for 5 days.",
                        topRightTag: .capsule("Confidence: 92%"),
                        bottomRightTag: nil,
                        trailingIcon: nil
                    )

                    InsightCard(
                        title: "Mood & Sleep Correlation",
                        subtitle: "Mood improves by ~20% with 7–8h sleep",
                        topRightTag: nil,
                        bottomRightTag: .text("Trend: Positive"),
                        trailingIcon: AnyView(
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        )
                    )

                    InsightCard(
                        title: "Activity Insight",
                        subtitle: "Afternoon walks improve energy & mood",
                        topRightTag: .capsule("New"),
                        bottomRightTag: nil,
                        trailingIcon: AnyView(
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        )
                    )
                }

                // Actions
                VStack(spacing: 16) {
                    PrimaryButton(title: "View Detailed Report") {
                        // TODO: navigate to detail screen
                    }

                    SecondaryButton(title: "Share Insights") {
                        // TODO: share action
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// MARK: - Components

private enum TagStyle {
    case capsule(String)
    case text(String)
}

private struct InsightCard: View {
    let title: String
    let subtitle: String
    let topRightTag: TagStyle?
    let bottomRightTag: TagStyle?
    let trailingIcon: AnyView?     // <- Accept any styled view

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.lcLavenderSoft)
                .shadow(color: .lcCardShadow, radius: 10, y: 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    if case let .capsule(text) = topRightTag {
                        Text(text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.lcLavender.opacity(0.35))
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Spacer()
                    if case let .text(text) = bottomRightTag {
                        Text(text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    if let trailingIcon {
                        trailingIcon
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .accessibilityElement(children: .combine)
    }
}

private struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.lcLavender)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.lcCardShadow, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
                .frame(height: 48)
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

// MARK: - Preview
#Preview {
    NavigationStack {
        InsightsOverviewView()
    }
}

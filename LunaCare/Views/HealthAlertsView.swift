
//
//  HealthAlertsView.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-07.
//


import SwiftUI

private extension Color {
    static let lcLavender      = Color(red: 0.74, green: 0.68, blue: 0.95)
    static let lcLavenderSoft  = Color(red: 0.96, green: 0.95, blue: 0.99)
    static let lcCardShadow    = Color.black.opacity(0.10)
    static let lcWarningRed    = Color(red: 0.93, green: 0.34, blue: 0.34)
}

// simple flag so demo notifications only fire once
private let demoAlertsScheduledKey = "LC_DemoAlertsScheduled"

struct HealthAlertsView: View {
    @EnvironmentObject var vm: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                header

                if vm.isLoading {
                    ProgressView("Checking alerts…")
                        .padding(.top, 20)

                } else if !vm.hasAlerts && !vm.hasRiskScore {
                    noAlertsView

                } else {
                    VStack(spacing: 16) {
                        ForEach(vm.alertInsights) { insight in
                            AlertCard(insight: insight)
                        }
                        if let score = vm.ppdRiskScore {
                            PPDModelAlertCard(
                                score: score,
                                thresholdPercent: vm.highPPDScoreThresholdPercent,
                                isHighScore: vm.highPPDRiskScore != nil
                            )
                        }
                    }
                }

                if let message = vm.riskAssessmentMessage {
                    riskAssessmentStatus(message)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduleDemoNotificationsIfNeeded()
        }
    }

    // MARK: - Demo notification trigger

    private func scheduleDemoNotificationsIfNeeded() {
        // Only schedule once for this demo
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: demoAlertsScheduledKey) == false else { return }
        guard !vm.alertInsights.isEmpty else { return }

        // Use your existing notification manager (already used in InsightsOverviewView)
        NotificationManager.shared.scheduleHealthAlertsIfNeeded(from: vm.alertInsights)

        defaults.set(true, forKey: demoAlertsScheduledKey)
    }

    // MARK: - UI Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text("Health Alerts")
                .font(.system(.title, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text("Red flags use weekly trend rules. ML alerts appear at model scores of \(vm.highPPDScoreThresholdPercent)% or higher.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var noAlertsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(.green)

            Text("No active alerts 🎉")
                .font(.system(size: 17, weight: .semibold))

            Text("No data-based red flags or high model-score alerts are active. Trend checks need at least five days of data in each of the two complete weeks.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }

    private func riskAssessmentStatus(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.lcLavenderSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Alert Card

private struct AlertCard: View {
    let insight: WeeklyInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.lcWarningRed)

                Text(insight.metric.capitalized)
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                severityBadge
            }

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: 8) {
                Text(insight.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Label("Compared with the previous week", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.lcLavenderSoft)
                .shadow(color: Color.lcCardShadow, radius: 10, y: 6)
        )
    }

    // MARK: - Badge

    private var severityBadge: some View {
        Text("Red flag")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.lcWarningRed)
            .clipShape(Capsule())
    }
}

private struct PPDModelAlertCard: View {
    let score: Double
    let thresholdPercent: Int
    let isHighScore: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PPD model score", systemImage: "brain.head.profile")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isHighScore ? .lcWarningRed : .primary)
                Spacer()
                Text("\(Int((score * 100).rounded()))%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }

            ProgressView(value: score, total: 1)
                .tint(isHighScore ? .lcWarningRed : .lcLavender)

            Text(isHighScore
                 ? "High-score alert: at or above the \(thresholdPercent)% cutoff."
                 : "Below the \(thresholdPercent)% alert cutoff.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isHighScore ? .lcWarningRed : .secondary)

            Text("Raw model output: \(String(format: "%.3f", score)) on a 0–1 scale. This is not verified confidence, a calibrated probability, or a diagnosis.")
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.lcLavenderSoft)
                .shadow(color: Color.lcCardShadow, radius: 10, y: 6)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthAlertsView()
            .environmentObject(
                InsightsViewModel(auth: AuthViewModel(),
                                  env: AppEnvironment.shared)
            )
    }
}

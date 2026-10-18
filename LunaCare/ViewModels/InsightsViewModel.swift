//
//  InsightsViewModel.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-29.
//

//
//  InsightsViewModel.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-29.
//

import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {

    private static let highPPDScoreThreshold = 0.90

    @Published var insights: [WeeklyInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published private(set) var ppdRiskScore: Double?
    @Published private(set) var riskAssessmentMessage: String?
    @Published private(set) var metricCoverage: [String: InsightMetricCoverage] = [:]

    private let auth: AuthViewModel
    private let env: AppEnvironment
    private let service = InsightService.shared

    init(auth: AuthViewModel, env: AppEnvironment) {
        self.auth = auth
        self.env = env
    }

    // MARK: - LOAD INSIGHTS

    func loadInsights(includeRiskAssessment: Bool = false) async {
        isLoading = true
        errorMessage = nil

        let snapshot = await service.loadSnapshot(uid: auth.uid)
        let weekly = snapshot.insights

        // Save to Firestore only if authenticated and cloud sync is on
        if !auth.uid.isEmpty && env.isCloudSyncOn {
            weekly.forEach { insight in
                env.insightsRepo?.saveInsight(insight)
            }
        }

        insights = weekly
        metricCoverage = snapshot.metricCoverage
        if includeRiskAssessment {
            await loadRiskAssessment(using: snapshot)
        } else {
            ppdRiskScore = nil
            riskAssessmentMessage = nil
        }
        isLoading = false
    }

    private func loadRiskAssessment(using snapshot: InsightDataSnapshot) async {
        ppdRiskScore = nil
        riskAssessmentMessage = nil

        if let loadErrorMessage = snapshot.loadErrorMessage {
            riskAssessmentMessage = "Model alert skipped because health data could not be loaded: \(loadErrorMessage)"
            return
        }

        if !auth.uid.isEmpty {
            do {
                let consent = try await PrivacyRepository().fetchConsent(uid: auth.uid)
                guard consent.riskInsights else {
                    riskAssessmentMessage = "ML risk alerts are off because Risk Insights consent is disabled."
                    return
                }
            } catch {
                riskAssessmentMessage = "ML risk alert skipped because Risk Insights consent could not be verified: \(error.localizedDescription)"
                return
            }
        }

        let calendar = Calendar.current
        let dataDays = Set(snapshot.measurements.map {
            calendar.startOfDay(for: $0.createdAt)
        })
        guard dataDays.count >= 5 else {
            riskAssessmentMessage = "ML risk alerts need at least five distinct days of health or check-in data in the past 30 days."
            return
        }

        do {
            ppdRiskScore = try PPDRiskModelRunner.shared.predictRisk(from: snapshot.measurements)
        } catch {
            riskAssessmentMessage = "ML risk alert could not be calculated: \(error.localizedDescription)"
        }
    }

    var isGuestMode: Bool { auth.uid.isEmpty }

    // MARK: - Alerts
    var alertInsights: [WeeklyInsight] {
        RiskAlertScheduler.redFlagInsights(from: insights)
    }

    var highPPDRiskScore: Double? {
        guard let ppdRiskScore,
              ppdRiskScore >= RecommendationEngine.highPPDScoreThreshold else { return nil }
        return ppdRiskScore
    }

    var hasRiskScore: Bool {
        ppdRiskScore != nil
    }

    var highPPDScoreThresholdPercent: Int {
        Int((RecommendationEngine.highPPDScoreThreshold * 100).rounded())
    }

    var hasAlerts: Bool {
        !alertInsights.isEmpty || highPPDRiskScore != nil
    }

    var alertCount: Int {
        alertInsights.count + (highPPDRiskScore == nil ? 0 : 1)
    }

    var alertMetricNames: [String] {
        var names = alertInsights
            .prefix(highPPDRiskScore == nil ? 2 : 1)
            .map(\.metric)
        if highPPDRiskScore != nil {
            names.append("PPD model score")
        }
        return names
    }

    // MARK: - Recommendations
    var recommendations: [RecommendationEngine.RecommendationItem] {
        RecommendationEngine.build(from: insights, ppdRiskScore: ppdRiskScore)
    }

    var eligibleMetricCount: Int {
        metricCoverage.values.filter(\.isSufficient).count
    }

    func coverage(for metric: String) -> InsightMetricCoverage? {
        metricCoverage[metric]
    }
}

//
//  InsightsViewModel.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2025-11-29.
//

import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {

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

    private var loadTask: Task<Void, Never>?
    private var loadedUID: String?

    // MARK: - Load Insights

    func loadIfNeeded() async {
        guard loadedUID != auth.uid else { return }
        await loadInsights(includeRiskAssessment: true)
    }

    func loadInsights(includeRiskAssessment: Bool = false) async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await performLoad(includeRiskAssessment: includeRiskAssessment) }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad(includeRiskAssessment: Bool) async {
        isLoading = true
        errorMessage = nil

        let uid = auth.uid
        let snapshot = await service.loadSnapshot(uid: uid)
        let weekly = snapshot.insights
        let isFreshData = snapshot.loadErrorMessage == nil

        if isFreshData, !auth.uid.isEmpty, env.isCloudSyncOn, let repo = env.insightsRepo {
            Task { await repo.syncInsights(weekly) }
        }

        insights = weekly
        metricCoverage = snapshot.metricCoverage
        if let loadError = snapshot.loadErrorMessage {
            errorMessage = "Showing saved insights because the latest data couldn’t be loaded: \(loadError)"
        }
        if isFreshData {
            RiskAlertScheduler.shared.scheduleIfNeeded(from: weekly)
        }

        if includeRiskAssessment {
            await loadRiskAssessment(loadFailed: !isFreshData, loadError: snapshot.loadErrorMessage)
        } else {
            ppdRiskScore = nil
            riskAssessmentMessage = nil
        }
        loadedUID = uid
        isLoading = false
    }

    private func loadRiskAssessment(loadFailed: Bool, loadError: String?) async {
        ppdRiskScore = nil
        riskAssessmentMessage = nil

        if loadFailed {
            riskAssessmentMessage = "Model alert skipped because health data could not be loaded: \(loadError ?? "unknown error")"
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

        let window: [Measurement]
        do {
            let fromCloud = !auth.uid.isEmpty && env.isCloudSyncOn
            let loader = PPDWindowLoader()
            guard try await loader.hasMonthOfHistory(uid: auth.uid, fromCloud: fromCloud) else {
                riskAssessmentMessage = PPDWindowLoader.notEnoughHistoryMessage
                return
            }
            window = try await loader.load(uid: auth.uid, fromCloud: fromCloud)
        } catch {
            riskAssessmentMessage = "ML risk alert could not be calculated: \(error.localizedDescription)"
            return
        }

        let dataDays = Set(window.map(\.dayKey))
        guard dataDays.count >= 5 else {
            riskAssessmentMessage = "ML risk alerts need at least five distinct days of health or check-in data in the past 30 days."
            return
        }

        guard let runner = PPDRiskModelRunner.shared else {
            riskAssessmentMessage = "ML risk alert could not be calculated: model unavailable."
            return
        }

        do {
            let score = try await Task.detached(priority: .utility) { try runner.predictRisk(from: window) }.value
            ppdRiskScore = score
            NotificationManager.shared.schedulePPDHighRiskAlertIfNeeded(score: score)
        } catch {
            riskAssessmentMessage = "ML risk alert could not be calculated: \(error.localizedDescription)"
        }
    }

    var isGuestMode: Bool { auth.uid.isEmpty }

    // MARK: - Alerts
    var alertInsights: [WeeklyInsight] {
        RiskAlertScheduler.redFlagInsights(from: insights)
    }

    var ppdRiskTier: PPDRiskTier? {
        ppdRiskScore.map(PPDRiskTier.init(score:))
    }

    var highPPDRiskScore: Double? {
        ppdRiskTier == .high ? ppdRiskScore : nil
    }

    var hasRiskScore: Bool {
        ppdRiskScore != nil
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

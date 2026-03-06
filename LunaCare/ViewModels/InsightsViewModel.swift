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

    @Published var insights: [WeeklyInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let auth: AuthViewModel
    private let env: AppEnvironment
    private let service = InsightService.shared

    init(auth: AuthViewModel, env: AppEnvironment) {
        self.auth = auth
        self.env = env
    }

    // MARK: - LOAD INSIGHTS

    func loadInsights() async {
        guard !auth.uid.isEmpty else {
            errorMessage = "User not signed in."
            return
        }

        isLoading = true
        errorMessage = nil

        // 🧠 Local ML-based insights generation
        let weekly = await service.loadInsights(uid: auth.uid)

        // 🔥 Save to Firestore if cloud sync ON
        if env.isCloudSyncOn {
            weekly.forEach { insight in
                env.insightsRepo?.saveInsight(insight)
            }
        }

        // 🔄 Always reflect latest UI state
        Task { @MainActor in
            self.insights = weekly
            self.isLoading = false
        }
    }

    // MARK: - Alerts
    var alertInsights: [WeeklyInsight] {
        insights.filter {
            $0.text.lowercased().contains("decline")
        }
    }

    // MARK: - Recommendations
    var recommendations: [RecommendationEngine.RecommendationItem] {
        RecommendationEngine.build(from: insights)
    }
}

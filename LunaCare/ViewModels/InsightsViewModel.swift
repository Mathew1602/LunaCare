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
        isLoading = true
        errorMessage = nil

        let weekly = await service.loadInsights(uid: auth.uid)

        // Save to Firestore only if authenticated and cloud sync is on
        if !auth.uid.isEmpty && env.isCloudSyncOn {
            weekly.forEach { insight in
                env.insightsRepo?.saveInsight(insight)
            }
        }

        insights = weekly
        isLoading = false
    }

    var isGuestMode: Bool { auth.uid.isEmpty }

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

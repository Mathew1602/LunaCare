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
    
     let auth: AuthViewModel
     let env: AppEnvironment
     let service = InsightService.shared
    
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
        
        let weekly = await service.loadInsights(uid: auth.uid)
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

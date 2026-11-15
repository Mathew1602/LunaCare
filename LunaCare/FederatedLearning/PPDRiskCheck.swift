//
//  PPDRiskCheck.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-11-05.
//

import Foundation

enum PPDRiskCheck {
    struct Result {
        let score: Double?
        let message: String?
        let dataDays: Int

        var watchSummary: WatchRiskSummary {
            WatchRiskSummary(score: score, message: message, computedAt: Date())
        }
    }

    static func run(uid: String, fromCloud: Bool) async -> Result {
        do {
            if !uid.isEmpty, try await !PrivacyRepository().fetchConsent(uid: uid).riskInsights {
                return Result(score: nil, message: "Risk insights are turned off in Data Privacy.", dataDays: 0)
            }

            let loader = PPDWindowLoader()
            guard try await loader.hasMonthOfHistory(uid: uid, fromCloud: fromCloud) else {
                return Result(score: nil, message: PPDWindowLoader.notEnoughHistoryMessage, dataDays: 0)
            }

            let records = try await loader.load(uid: uid, fromCloud: fromCloud)
            guard !records.isEmpty else {
                return Result(score: nil, message: "No measurements in the last 30 days. Log data or sync your watch first.", dataDays: 0)
            }
            guard let runner = PPDRiskModelRunner.shared else {
                return Result(score: nil, message: "Model unavailable", dataDays: records.count)
            }
            let score = try runner.predictRisk(from: records)
            return Result(score: score, message: nil, dataDays: records.count)
        } catch {
            return Result(score: nil, message: "Couldn’t run model: \(error.localizedDescription)", dataDays: 0)
        }
    }
}

//
//  PPDRiskModelRunner.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//  Updated to include fatigue_1to10
//

import Foundation
import CoreML

final class PPDRiskModelRunner {

    static let shared = PPDRiskModelRunner()

    private let model: MLModel
    private let featureExtractor = PPDFeaturePipeline()

    private init() {
        guard let url = Bundle.main.url(forResource: "PPDRiskModel", withExtension: "mlmodelc") else {
            fatalError("PPDRiskModel.mlmodelc not found in app bundle.")
        }

        do {
            model = try MLModel(contentsOf: url)
        } catch {
            fatalError("Failed to load PPDRiskModel: \(error)")
        }
    }

    func predictRisk(from records: [LunaCare.Measurement]) throws -> Double {

        let features = featureExtractor.makeFeatureVector(from: records)
        let provider = try MLDictionaryFeatureProvider(dictionary: features)
        let output = try model.prediction(from: provider)

        if let score = output.featureValue(for: "ppd_risk_score_0to1")?.doubleValue,
           score.isFinite,
           (0.0...1.0).contains(score) {
            return score
        }

        throw NSError(domain: "PPDRiskModelRunner",
                      code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Model output ppd_risk_score_0to1 is missing or outside 0-1."])
    }
}

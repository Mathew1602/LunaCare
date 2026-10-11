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

    enum RunnerError: LocalizedError {
        case modelNotFound
        case invalidOutput

        var errorDescription: String? {
            switch self {
            case .modelNotFound: return "Model unavailable"
            case .invalidOutput: return "Model output missing/invalid"
            }
        }
    }

    static let bundledModelURL = Bundle.main.url(forResource: "PPDRiskModel", withExtension: "mlmodelc")

    /// Downloaded model (ModelUpdateService) if present and loadable, else the bundled one.
    static let shared: PPDRiskModelRunner? = {
        if let url = ModelUpdateService.installedModelURL(),
           let runner = try? PPDRiskModelRunner(modelURL: url) {
            return runner
        }
        ModelUpdateService.resetToBundled()
        return try? PPDRiskModelRunner()
    }()

    static let outputName = "ppd_risk_score_0to1"

    private var model: MLModel
    private let lock = NSLock()
    private let featureExtractor = PPDFeaturePipeline()

    init(modelURL: URL? = PPDRiskModelRunner.bundledModelURL) throws {
        guard let modelURL else { throw RunnerError.modelNotFound }
        model = try MLModel(contentsOf: modelURL)
    }

    func reload(from modelURL: URL) throws {
        let newModel = try MLModel(contentsOf: modelURL)
        lock.withLock { model = newModel }
    }

    func predictRisk(from records: [LunaCare.Measurement], windowEnd: Date = Date()) throws -> Double {
        try predictRisk(features: featureExtractor.makeFeatureVector(from: records, windowEnd: windowEnd))
    }

    func predictRisk(features: [String: MLFeatureValue]) throws -> Double {
        let current = lock.withLock { model }
        let provider = try MLDictionaryFeatureProvider(dictionary: features)
        let output = try current.prediction(from: provider)

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

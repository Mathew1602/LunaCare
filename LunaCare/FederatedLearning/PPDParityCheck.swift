//
//  PPDParityCheck.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-11.
//

#if DEBUG
import Foundation

/// Compares Swift features + Core ML score against ppd_parity_fixture.json
/// (federated-learning/scripts/export_parity_fixture.py). Prints PASS/FAIL to the console.
enum PPDParityCheck {

    private struct Fixture: Decodable {
        let featureSchemaVersion: Int
        let windowEnd: Date
        let featureTolerance: Double
        let predictionTolerance: Double
        let cases: [Case]
    }

    private struct Case: Decodable {
        let name: String
        let measurements: [Measurement]
        let features: [String: Double?]
        let prediction: Double
    }

    @discardableResult
    static func run(bundle: Bundle = .main) -> Bool {
        guard let url = bundle.url(forResource: "ppd_parity_fixture", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[PPDParity] FAIL: fixture not found in bundle")
            return false
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture: Fixture
        do {
            fixture = try decoder.decode(Fixture.self, from: data)
        } catch {
            print("[PPDParity] FAIL: fixture decode error \(error)")
            return false
        }

        guard fixture.featureSchemaVersion == PPDFeaturePipeline.featureSchemaVersion else {
            print("[PPDParity] FAIL: schema \(fixture.featureSchemaVersion) != \(PPDFeaturePipeline.featureSchemaVersion)")
            return false
        }

        let pipeline = PPDFeaturePipeline()
        var passed = true

        for c in fixture.cases {
            let swift = pipeline.rawFeatures(from: c.measurements, windowEnd: fixture.windowEnd)
            var mismatches: [String] = []

            for name in PPDFeaturePipeline.featureNames {
                let expected = c.features[name] ?? nil
                let got = swift[name] ?? nil
                switch (expected, got) {
                case (nil, nil): continue
                case let (e?, g?) where abs(e - g) <= fixture.featureTolerance: continue
                default: mismatches.append("\(name): python \(String(describing: expected)) swift \(String(describing: got))")
                }
            }

            var scoreLine = "score skipped (bundled model unavailable)"
            if let runner = try? PPDRiskModelRunner() {
                do {
                    let score = try runner.predictRisk(from: c.measurements, windowEnd: fixture.windowEnd)
                    let diff = abs(score - c.prediction)
                    scoreLine = String(format: "score %.6f vs %.6f (diff %.2e)", score, c.prediction, diff)
                    if diff > fixture.predictionTolerance { mismatches.append(scoreLine) }
                } catch {
                    mismatches.append("prediction error \(error.localizedDescription)")
                }
            } else {
                mismatches.append(scoreLine)
            }

            if mismatches.isEmpty {
                print("[PPDParity] PASS \(c.name): 168 features, \(scoreLine)")
            } else {
                passed = false
                print("[PPDParity] FAIL \(c.name):\n  " + mismatches.joined(separator: "\n  "))
            }
        }
        return passed
    }
}
#endif

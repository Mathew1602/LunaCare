//
//  ModelUpdateService.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2026-10-11.
//

import Foundation
import CoreML
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Downloads the model published at ml_models/current, verifies it (sha256 + persona scores
/// from metrics.json), compiles it on device and hot-swaps PPDRiskModelRunner.
actor ModelUpdateService {

    static let shared = ModelUpdateService()
    static let bundledVersion = 1
    static let didUpdateNotification = Notification.Name("ModelUpdateService.didUpdate")

    private static let versionKey = "ml_modelVersion"
    private static let updatedAtKey = "ml_modelUpdatedAt"
    private static let lastCheckKey = "ml_lastCheckAt"
    private static let rejectedVersionKey = "ml_rejectedVersion"
    private static let modelFileName = "PPDRiskModel.mlmodelc"

    private let checkInterval: TimeInterval = 6 * 60 * 60
    private let personaTolerance = 1e-4
    private let maxMetricsBytes: Int64 = 1 * 1024 * 1024
    private var inFlight: Task<Void, Error>?

    enum UpdateError: LocalizedError {
        case checksumMismatch
        case personaMismatch(String)
        case missingPersonaData

        var errorDescription: String? {
            switch self {
            case .checksumMismatch: return "Downloaded model checksum mismatch"
            case .personaMismatch(let detail): return "Downloaded model failed persona check: \(detail)"
            case .missingPersonaData: return "Published model has no persona scores to verify against"
            }
        }
    }

    private init() {}

    // MARK: - Installed model state

    nonisolated static var currentVersion: Int {
        let stored = UserDefaults.standard.integer(forKey: versionKey)
        return stored > bundledVersion ? stored : bundledVersion
    }

    nonisolated static var updatedAt: Date? {
        UserDefaults.standard.object(forKey: updatedAtKey) as? Date
    }

    nonisolated static func installedModelURL() -> URL? {
        let version = UserDefaults.standard.integer(forKey: versionKey)
        guard version > bundledVersion, let dir = try? folder(for: version) else { return nil }
        let url = dir.appendingPathComponent(modelFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated static func resetToBundled() {
        UserDefaults.standard.removeObject(forKey: versionKey)
        UserDefaults.standard.removeObject(forKey: updatedAtKey)
    }

    private nonisolated static func modelsDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    private nonisolated static func folder(for version: Int) throws -> URL {
        try modelsDirectory().appendingPathComponent("v\(version)", isDirectory: true)
    }

    // MARK: - Update

    /// Concurrent callers (e.g. quick inactive -> active flips) join the running check instead of racing it.
    func checkForUpdate(force: Bool = false) async {
        if let inFlight {
            _ = try? await inFlight.value
            return
        }
        let task = Task { try await update(force: force) }
        inFlight = task
        defer { inFlight = nil }
        do {
            try await task.value
        } catch {
            // A published model that fails verification is skipped until a newer version appears;
            // only transient errors (network, disk) retry on the next foreground.
            if !(error is UpdateError) {
                UserDefaults.standard.removeObject(forKey: Self.lastCheckKey)
            }
            print("[ModelUpdate] failed: \(error.localizedDescription)")
        }
    }

    private func update(force: Bool) async throws {
        guard Auth.auth().currentUser != nil else { return }
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < checkInterval {
            return
        }

        let data = try await Firestore.firestore().document("ml_models/current").getDocument().data() ?? [:]
        defaults.set(Date(), forKey: Self.lastCheckKey)

        guard let version = data["version"] as? Int,
              let mlmodelPath = data["mlmodelPath"] as? String,
              let expectedSHA = data["sha256"] as? String,
              version > Self.currentVersion,
              version != defaults.integer(forKey: Self.rejectedVersionKey) else { return }
        guard let metricsPath = data["metricsPath"] as? String else { throw reject(version, .missingPersonaData) }
        guard data["featureSchemaVersion"] as? Int == PPDFeaturePipeline.featureSchemaVersion else {
            print("[ModelUpdate] skipped v\(version): feature schema \(data["featureSchemaVersion"] ?? "nil")")
            return
        }

        let fm = FileManager.default
        let download = fm.temporaryDirectory.appendingPathComponent("PPDRiskModel_v\(version).mlmodel")
        try? fm.removeItem(at: download)
        defer { try? fm.removeItem(at: download) }

        _ = try await Storage.storage().reference(withPath: mlmodelPath).writeAsync(toFile: download)
        guard try sha256(of: download) == expectedSHA else { throw reject(version, .checksumMismatch) }

        let compiled = try await MLModel.compileModel(at: download)
        defer { try? fm.removeItem(at: compiled) }

        let folder = try Self.folder(for: version)
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(Self.modelFileName)
        try fm.moveItem(at: compiled, to: dest)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folderURL = folder
        try? folderURL.setResourceValues(values)

        do {
            let model = try MLModel(contentsOf: dest)
            try await verifyPersonas(model, metricsPath: metricsPath)
            try PPDRiskModelRunner.shared?.reload(from: dest)
        } catch {
            try? fm.removeItem(at: folder)
            if let updateError = error as? UpdateError { throw reject(version, updateError) }
            throw error
        }

        let previous = Self.currentVersion
        defaults.set(version, forKey: Self.versionKey)
        defaults.set(Date(), forKey: Self.updatedAtKey)
        prune(keeping: [version, previous])
        print("[ModelUpdate] switched to v\(version)")
        await MainActor.run { NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil) }
    }

    private func reject(_ version: Int, _ error: UpdateError) -> UpdateError {
        UserDefaults.standard.set(version, forKey: Self.rejectedVersionKey)
        return error
    }

    /// metrics.json carries the 3 notebook personas and the XGBoost scores the function computed.
    private func verifyPersonas(_ model: MLModel, metricsPath: String) async throws {
        let raw = try await Storage.storage().reference(withPath: metricsPath).data(maxSize: maxMetricsBytes)
        guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let scores = json["persona_scores"] as? [String: Double],
              let features = json["persona_features"] as? [String: [String: Double]],
              !scores.isEmpty else { throw UpdateError.missingPersonaData }

        for (name, expected) in scores {
            guard let values = features[name] else { throw UpdateError.missingPersonaData }
            let provider = try MLDictionaryFeatureProvider(dictionary: values.mapValues { MLFeatureValue(double: $0) })
            let output = try await model.prediction(from: provider)
            let got = output.featureValue(for: PPDRiskModelRunner.outputName)?.doubleValue ?? .nan
            guard abs(got - expected) <= personaTolerance else {
                throw UpdateError.personaMismatch("\(name) \(got) vs \(expected)")
            }
        }
    }

    private func prune(keeping versions: Set<Int>) {
        let fm = FileManager.default
        guard let root = try? Self.modelsDirectory(),
              let folders = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let keep = Set(versions.map { "v\($0)" })
        for folder in folders where !keep.contains(folder.lastPathComponent) {
            try? fm.removeItem(at: folder)
        }
    }

    private func sha256(of url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
}

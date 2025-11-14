//
//  WatchConnectivityManager.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-14.
//

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {


    static let shared = WatchConnectivityManager()

    @Published var lastReceived: SyncMessage? = nil
    @Published var errorMessage: String?

    private var session: WCSession?


    private override init() {
        super.init()
        startSession()
    }
    func activate() {
        startSession()
    }

    // MARK: - Session setup

    private func startSession() {
        guard WCSession.isSupported() else {
            print("Watch Connectivity is not supported on this device.")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Sending

    /// Generic send for any Codable payload, mirroring your original API.
    func send<T: Codable>(_ model: T, type: SyncType) {
        guard let session = session else {
            errorMessage = "WCSession not initialized."
            print(errorMessage ?? "")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(model),
              let string = String(data: data, encoding: .utf8) else {
            errorMessage = "Failed to encode model for type \(type)."
            print(errorMessage ?? "")
            return
        }

        let message: [String: Any] = [
            "type": type.rawValue,
            "payload": string
        ]

        // Prefer immediate message when reachable, else fall back to background transfer
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                self.errorMessage = "Failed to send message: \(error.localizedDescription)"
                print(self.errorMessage ?? "")
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Receiving

    private func handleIncoming(_ message: [String: Any]) {
        guard let typeString = message["type"] as? String,
              let payload = message["payload"] as? String,
              let type = SyncType(rawValue: typeString),
              let data = payload.data(using: .utf8) else {
            print("Received invalid message format: \(message)")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch type {

        case .moodLog:
            if let mood = try? decoder.decode(MoodLog.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, moodLog: mood)
                }
            }

        case .measurement:
            if let measurement = try? decoder.decode(Measurement.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, measurement: measurement)
                }
            }

        case .insight:
            if let insight = try? decoder.decode(Insight.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, insight: insight)
                }
            }

        case .profile:
            if let profile = try? decoder.decode(UserProfile.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, profile: profile)
                }
            }
        }
    }

    // Immediate messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncoming(message)
    }

    // Background userInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        handleIncoming(userInfo)
    }

    // MARK: - Activation & lifecycle

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            errorMessage = "WCSession activation failed: \(error.localizedDescription)"
            print(errorMessage ?? "")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // No-op, but required on iOS
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // After deactivation, the session needs to be reactivated
        WCSession.default.activate()
    }
    #endif
}

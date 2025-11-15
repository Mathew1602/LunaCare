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
            print("WatchConnectivity not supported on this device.")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Sending

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

        print("Sending message:")
        print("- Type: \(type.rawValue)")
        print("- Payload: \(string)")
        print("- Reachable: \(session.isReachable)")

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                self.errorMessage = "Failed to send message: \(error.localizedDescription)"
                print(self.errorMessage ?? "")
            }
        } else {
            print("Device not reachable. Using transferUserInfo()")
            session.transferUserInfo(message)
        }
    }

    // MARK: - Receiving

    private func handleIncoming(_ message: [String: Any]) {

        print("Incoming raw message: \(message)")

        guard let typeString = message["type"] as? String,
              let payload = message["payload"] as? String,
              let type = SyncType(rawValue: typeString),
              let data = payload.data(using: .utf8) else {

            print("Invalid message format.")
            return
        }

        print("Decoding incoming message:")
        print("- Type: \(typeString)")
        print("- Payload JSON: \(payload)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch type {

        case .moodLog:
            if let mood = try? decoder.decode(MoodLog.self, from: data) {
                print("Decoded MoodLog: \(mood)")
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, moodLog: mood)
                }
            } else {
                print("Failed to decode MoodLog")
            }
            
        case .symptomLog:
            if let payload = try? decoder.decode(SymptomLogPayload.self, from: data) {
                print("Decoded SymptomLogPayload: \(payload)")
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, symptomLog: payload)
                }
            } else {
                print("Failed to decode SymptomLogPayload")
            }

        case .measurement:
            if let measurement = try? decoder.decode(Measurement.self, from: data) {
                print("Decoded Measurement: \(measurement)")
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, measurement: measurement)
                }
            } else {
                print("Failed to decode Measurement")
            }

        case .insight:
            if let insight = try? decoder.decode(Insight.self, from: data) {
                print("Decoded Insight: \(insight)")
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, insight: insight)
                }
            } else {
                print("Failed to decode Insight")
            }

        case .profile:
            if let profile = try? decoder.decode(UserProfile.self, from: data) {
                print("Decoded UserProfile: \(profile)")
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, profile: profile)
                }
            } else {
                print("Failed to decode UserProfile")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("didReceiveMessage triggered")
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("didReceiveUserInfo triggered")
        handleIncoming(userInfo)
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession didBecomeInactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession didDeactivate — reactivating")
        WCSession.default.activate()
    }
    #endif
}

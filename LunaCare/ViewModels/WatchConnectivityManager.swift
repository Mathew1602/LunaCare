import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()

    @Published var lastReceived: SyncMessage? = nil
    @Published var lastProfile: UserProfile? = nil {
        didSet { persistProfile(lastProfile) }
    }
    @Published var errorMessage: String?

    private var session: WCSession?

    private let profileCacheKey = "lc_lastProfile_cache"

    private override init() {
        super.init()
        loadCachedProfile()
        startSession()
    }

    func activate() {
        startSession()
    }

    private func startSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device.")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()

        // If iPhone already set context, grab it now
        if let context = session?.receivedApplicationContext, !context.isEmpty {
            handleIncoming(context)
        }
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

        //If sending profile, also have to update application context on iOS
        #if os(iOS)
        if type == .profile {
            do {
                try session.updateApplicationContext(message)
                print("Updated application context with profile.")
            } catch {
                print("Failed to update application context: \(error)")
            }
        }
        #endif

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
            print("Invalid message format.")
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

        case .symptomLog:
            if let payload = try? decoder.decode(SymptomLogPayload.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, symptomLog: payload)
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
                    self.lastProfile = profile
                    self.lastReceived = SyncMessage(type: type, profile: profile)
                }
            }

        case .getMoodRequest:
            if let request = try? decoder.decode(GetRequest.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, getMoodRequest: request)
                }
            }

        case .getMoodResponse:
            if let logs = try? decoder.decode([CalendarDayLog].self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, getMoodResponse: logs)
                }
            }

        case .getSymptomRequest:
            if let request = try? decoder.decode(GetRequest.self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, getSymptomRequest: request)
                }
            }

        case .getSymptomResponse:
            if let logs = try? decoder.decode([SymptomLogSummary].self, from: data) {
                DispatchQueue.main.async {
                    self.lastReceived = SyncMessage(type: type, getSymptomResponse: logs)
                }
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        handleIncoming(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncoming(applicationContext)
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif


    private func persistProfile(_ profile: UserProfile?) {
        guard let profile else { return }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileCacheKey)
        }
    }

    private func loadCachedProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        lastProfile = profile
    }
}

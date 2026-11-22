//
//  AppleWatchDataStore.swift
//  LunaCare
//
//  Created by Mathew Boyd on 2025-11-24.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class AppleWatchDataStore: ObservableObject {
    static let shared = AppleWatchDataStore()

    private let repo = AppleWatchDataRepository()
    private init() {}

    @Published var isAuthorized = false
    @Published private(set) var hasHealthDataAvailable = false
    @Published private(set) var hasHealthReadings = false

    @Published var stepsToday: Int = 0
    @Published var activeEnergyKcal: Double = 0
    @Published var restingHR: Double = 0
    @Published var sleepHours: Double = 0

    @Published var hrvSDNN: Double = 0
    @Published var respiratoryRate: Double = 0
    @Published var spo2: Double = 0
    @Published var vo2Max: Double = 0

    @Published var dailyMeasurements: [Measurement] = []
    @Published var latestMeasurement: Measurement? = nil

    func authorizeAndRefresh(lastDays: Int = 30) async {
        hasHealthDataAvailable = repo.isHealthDataAvailable
        guard hasHealthDataAvailable else {
            isAuthorized = false
            hasHealthReadings = false
            dailyMeasurements = []
            latestMeasurement = nil
            clearLatestValues()
            return
        }

        do {
            try await repo.requestAuthorization()
            isAuthorized = true
            await refresh(lastDays: lastDays)
        } catch {
            print("HealthKit auth error: \(error.localizedDescription)")
            isAuthorized = false
            hasHealthReadings = false
            dailyMeasurements = []
            latestMeasurement = nil
            clearLatestValues()
        }
    }

    func refresh(lastDays: Int = 30) async {
        guard isAuthorized else { return }

        let records = await repo.fetchDailyMeasurements(lastDays: lastDays)

        dailyMeasurements = records
        latestMeasurement = records.last
        hasHealthReadings = records.contains { record in
            record.steps != nil ||
            record.distanceWalkedKm != nil ||
            record.flightsClimbed != nil ||
            record.activeEnergyKcal != nil ||
            record.basalEnergyKcal != nil ||
            record.exerciseMinutes != nil ||
            record.standHours != nil ||
            record.avgHeartRateBpm != nil ||
            record.restingHRBpm != nil ||
            record.walkingHeartRateAvgBpm != nil ||
            record.sleepHours != nil ||
            record.deepSleepHours != nil ||
            record.remSleepHours != nil ||
            record.coreSleepHours != nil ||
            record.sleepEfficiencyPct != nil ||
            record.wakeAfterSleepOnsetMin != nil ||
            record.hrvSDNNms != nil ||
            record.respiratoryRateBpm != nil ||
            record.oxygenSaturationPct != nil ||
            record.vo2Max != nil || record.weightKg != nil
        }

        guard let today = records.last else {
            clearLatestValues()
            return
        }

        stepsToday = today.steps ?? 0
        activeEnergyKcal = today.activeEnergyKcal ?? 0
        restingHR = today.restingHRBpm ?? 0
        sleepHours = today.sleepHours ?? 0

        hrvSDNN = today.hrvSDNNms ?? 0
        respiratoryRate = today.respiratoryRateBpm ?? 0
        spo2 = today.oxygenSaturationPct ?? 0
        vo2Max = today.vo2Max ?? 0
    }

    private func clearLatestValues() {
        stepsToday = 0
        activeEnergyKcal = 0
        restingHR = 0
        sleepHours = 0
        hrvSDNN = 0
        respiratoryRate = 0
        spo2 = 0
        vo2Max = 0
    }
}

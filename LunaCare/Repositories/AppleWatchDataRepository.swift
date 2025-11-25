import Foundation
import HealthKit

final class AppleWatchDataRepository {
    private let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Activity / movement
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flights)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let stand = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(stand)
        }

        // Heart / cardio
        if let avgHR = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(avgHR)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let walkingHR = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(walkingHR)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let respRate = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respRate)
        }
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(spo2)
        }
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2)
        }

        // Body
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }

        // Sleep
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { _, err in
                if let err = err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    /// Returns DailyRecord for each day ending today, oldest -> newest.
    func fetchDailyMeasurements(lastDays: Int = 30) async -> [Measurement] {
         let cal = Calendar.current
         let todayStart = cal.startOfDay(for: Date())

         var days: [Measurement] = []
         days.reserveCapacity(lastDays)

         for offset in stride(from: lastDays - 1, through: 0, by: -1) {
             let start = cal.date(byAdding: .day, value: -offset, to: todayStart)!
             let end = cal.date(byAdding: .day, value: 1, to: start)!

             async let steps = dailySum(.stepCount, start, end, .count())
             async let distanceM = dailySum(.distanceWalkingRunning, start, end, .meter())
             async let flights = dailySum(.flightsClimbed, start, end, .count())
             async let activeEnergy = dailySum(.activeEnergyBurned, start, end, .kilocalorie())
             async let basalEnergy = dailySum(.basalEnergyBurned, start, end, .kilocalorie())
             async let exerciseMin = dailySum(.appleExerciseTime, start, end, .minute())
             async let standMin = dailySum(.appleStandTime, start, end, .minute())

             async let avgHR = dailyAverage(.heartRate, start, end, HKUnit.count().unitDivided(by: .minute()))
             async let restingHR = dailyAverage(.restingHeartRate, start, end, HKUnit.count().unitDivided(by: .minute()))
             async let walkingHR = dailyAverage(.walkingHeartRateAverage, start, end, HKUnit.count().unitDivided(by: .minute()))
             async let hrv = dailyAverage(.heartRateVariabilitySDNN, start, end, .secondUnit(with: .milli))
             async let respRate = dailyAverage(.respiratoryRate, start, end, HKUnit.count().unitDivided(by: .minute()))
             async let spo2 = dailyAverage(.oxygenSaturation, start, end, .percent())
             async let vo2 = latestInRange(.vo2Max, start, end, HKUnit(from: "ml/kg*min"))

             async let weightKg = latestInRange(.bodyMass, start, end, .gramUnit(with: .kilo))
             async let sleep = fetchSleepMetrics(nightEnding: end)

             let sleepMetrics = await sleep

             let measurement = Measurement(
                 id: nil,
                 createdAt: start,

                 // symptoms / mood (not HealthKit)
                 mood1to5: nil,
                 bleeding1to10: nil,
                 hairLoss1to10: nil,
                 appetiteIssue1to10: nil,
                 sleepTrouble1to10: nil,

                 // movement
                 steps: (await steps).map(Int.init),
                 distanceWalkedKm: (await distanceM).map { $0 / 1000.0 },
                 flightsClimbed: await flights,
                 activeEnergyKcal: await activeEnergy,
                 basalEnergyKcal: await basalEnergy,
                 exerciseMinutes: await exerciseMin,
                 standHours: (await standMin).map { $0 / 60.0 },
                 sunlightHours: nil,

                 // heart
                 avgHeartRateBpm: await avgHR,
                 restingHRBpm: await restingHR,
                 walkingHeartRateAvgBpm: await walkingHR,
                 hrvSDNNms: await hrv,
                 respiratoryRateBpm: await respRate,
                 oxygenSaturationPct: await spo2,
                 vo2Max: await vo2,

                 // sleep
                 sleepHours: sleepMetrics.sleepHours,
                 deepSleepHours: sleepMetrics.deepHours,
                 remSleepHours: sleepMetrics.remHours,
                 coreSleepHours: sleepMetrics.coreHours,
                 sleepEfficiencyPct: sleepMetrics.efficiencyPct,
                 wakeAfterSleepOnsetMin: sleepMetrics.wasoMin,

                 // body
                 weightKg: await weightKg,

                 source: "watch"
             )

             days.append(measurement)
         }

         return days
     }


    private struct SleepMetrics {
        let sleepHours: Double?
        let deepHours: Double?
        let remHours: Double?
        let coreHours: Double?
        let efficiencyPct: Double?
        let wasoMin: Double?
    }

    /// Gets sleep for the "night window" ending at `nightEnding`:
    private func fetchSleepMetrics(nightEnding: Date) async -> SleepMetrics {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return SleepMetrics(sleepHours: nil, deepHours: nil, remHours: nil, coreHours: nil, efficiencyPct: nil, wasoMin: nil)
        }

        let cal = Calendar.current
        let start = cal.date(bySettingHour: 18, minute: 0, second: 0,
                             of: nightEnding.addingTimeInterval(-86400))!
        let end   = cal.date(bySettingHour: 12, minute: 0, second: 0,
                             of: nightEnding)!

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: sleepType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: nil) { _, samples, _ in

                let cat = samples as? [HKCategorySample] ?? []

                func duration(_ filter: (HKCategorySample) -> Bool) -> Double {
                    cat.filter(filter).reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                }

                let asleepSeconds = duration {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }

                let deepSeconds = duration { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
                let remSeconds  = duration { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                let coreSeconds = duration { $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue }

                let inBedSeconds = duration { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }

                let awakeSeconds = duration { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }

                let sleepHours = asleepSeconds > 0 ? asleepSeconds / 3600.0 : nil
                let deepHours  = deepSeconds > 0 ? deepSeconds / 3600.0 : nil
                let remHours   = remSeconds  > 0 ? remSeconds  / 3600.0 : nil
                let coreHours  = coreSeconds > 0 ? coreSeconds / 3600.0 : nil

                let efficiency: Double?
                if inBedSeconds > 0 && asleepSeconds > 0 {
                    efficiency = (asleepSeconds / inBedSeconds) * 100.0
                } else {
                    efficiency = nil
                }

                let wasoMin = awakeSeconds > 0 ? awakeSeconds / 60.0 : nil

                cont.resume(returning: SleepMetrics(
                    sleepHours: sleepHours,
                    deepHours: deepHours,
                    remHours: remHours,
                    coreHours: coreHours,
                    efficiencyPct: efficiency,
                    wasoMin: wasoMin
                ))
            }

            self.healthStore.execute(query)
        }
    }


    private func dailySum(_ id: HKQuantityTypeIdentifier,
                          _ start: Date, _ end: Date,
                          _ unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }

        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: pred,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            self.healthStore.execute(q)
        }
    }

    private func dailyAverage(_ id: HKQuantityTypeIdentifier,
                              _ start: Date, _ end: Date,
                              _ unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }

        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: pred,
                                      options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            self.healthStore.execute(q)
        }
    }

    private func latestInRange(_ id: HKQuantityTypeIdentifier,
                               _ start: Date, _ end: Date,
                               _ unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }

        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type,
                                  predicate: pred,
                                  limit: 1,
                                  sortDescriptors: [sort]) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                cont.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            self.healthStore.execute(q)
        }
    }
}

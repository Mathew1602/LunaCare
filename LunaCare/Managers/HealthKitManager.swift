//
//  HealthKitManager.swift
//  LunaCare
//
//  Created by Fernanda Battig on 2026-09-27.
//

import HealthKit


final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            completion(success, error)
        }
    }

    func fetchRecentQuantity(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: false)
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, results, _ in
            guard let sample = results?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }

        healthStore.execute(query)
    }
}

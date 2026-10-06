//
//  HealthManager.swift
//  HeartRateView
//
//  Created by Allan Hull on 10/4/26.
//

import Foundation
import Combine
import HealthKit

@MainActor
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var heartRates: [HKQuantitySample] = []

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, error in
            guard let self = self else { return }
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
                return
            }

            if success {
                Task { @MainActor in
                    self.startHeartRateQuery()
                }
            } else {
                print("HealthKit authorization denied.")
            }
        }
    }

    private func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let anchoredQuery = HKAnchoredObjectQuery(type: heartRateType,
                                                  predicate: nil,
                                                  anchor: anchor,
                                                  limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, deletedObjectsOrNil, newAnchor, error in
            guard let self = self else { return }
            if let error = error {
                print("Anchored query initial error: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                self.anchor = newAnchor
                self.handle(samples: samplesOrNil)
            }
        }

        anchoredQuery.updateHandler = { [weak self] _, samplesOrNil, deletedObjectsOrNil, newAnchor, error in
            guard let self = self else { return }
            if let error = error {
                print("Anchored query update error: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                self.anchor = newAnchor
                self.handle(samples: samplesOrNil)
            }
        }

        heartRateQuery = anchoredQuery
        healthStore.execute(anchoredQuery)
    }

    private func handle(samples: [HKSample]?) {
        guard let samples = samples else { return }

        let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
            .sorted { $0.endDate > $1.endDate }

        let combined = (quantitySamples + self.heartRates).uniqueByUUID()
        self.heartRates = Array(combined.prefix(200))
    }

    // One-off fetch if you prefer not to use anchored/live updates
    func fetchLatestHeartRate(limit: Int = 20) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType,
                                  predicate: nil,
                                  limit: limit,
                                  sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                print("HKSampleQuery error: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                self?.heartRates = (samples as? [HKQuantitySample]) ?? []
            }
        }

        healthStore.execute(query)
    }
}

// MARK Swift helper to deduplicate samples by UUID
private extension Array where Element == HKQuantitySample {
    func uniqueByUUID() -> [HKQuantitySample] {
        var seen = Set<UUID>()
        var result: [HKQuantitySample] = []
        for sample in self {
            if !seen.contains(sample.uuid) {
                seen.insert(sample.uuid)
                result.append(sample)
            }
        }
        return result
    }
}

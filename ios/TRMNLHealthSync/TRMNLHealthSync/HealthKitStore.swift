import Foundation
import HealthKit

final class HealthKitStore {
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppModelError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.activitySummaryType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppModelError.healthDataUnavailable)
                }
            }
        }
    }

    func installObservers(onUpdate: @escaping @Sendable () async -> Void) {
        guard observerQueries.isEmpty else { return }

        let sampleTypes: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
        ]

        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, _ in
                Task {
                    defer { completionHandler() }
                    await onUpdate()
                }
            }
            observerQueries.append(query)
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }
        }
    }

    func fetchDailySnapshot(deviceName: String) async throws -> HealthSnapshot {
        let now = Date()
        let move = try await cumulativeSum(
            for: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: now.startOfDay
        )
        let exercise = try await cumulativeSum(
            for: .appleExerciseTime,
            unit: .minute(),
            start: now.startOfDay
        )
        let steps = try await cumulativeSum(
            for: .stepCount,
            unit: .count(),
            start: now.startOfDay
        )
        let distanceMeters = try await cumulativeSum(
            for: .distanceWalkingRunning,
            unit: .meter(),
            start: now.startOfDay
        )
        let flights = try await cumulativeSum(
            for: .flightsClimbed,
            unit: .count(),
            start: now.startOfDay
        )
        let summary = try await activitySummary(for: now)

        let moveGoal = Int(summary?.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()) ?? 0)
        let exerciseGoal = Int(summary?.appleExerciseTimeGoal.doubleValue(for: .minute()) ?? 0)
        let standGoal = Int(summary?.appleStandHoursGoal.doubleValue(for: .count()) ?? 0)
        let standHours = Int(summary?.appleStandHours.doubleValue(for: .count()) ?? 0)

        let moveInt = Int(move.rounded())
        let exerciseInt = Int(exercise.rounded())

        return HealthSnapshot(
            capturedAt: now,
            deviceName: deviceName,
            profileName: "Apple Health",
            steps: Int(steps.rounded()),
            distanceKilometers: distanceMeters / 1000,
            distanceMiles: distanceMeters / 1609.344,
            flightsClimbed: Int(flights.rounded()),
            moveKilocalories: moveInt,
            moveGoalKilocalories: moveGoal,
            movePercent: percent(current: moveInt, goal: moveGoal),
            exerciseMinutes: exerciseInt,
            exerciseGoalMinutes: exerciseGoal,
            exercisePercent: percent(current: exerciseInt, goal: exerciseGoal),
            standHours: standHours,
            standGoalHours: standGoal,
            standPercent: percent(current: standHours, goal: standGoal)
        )
    }

    private func cumulativeSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func activitySummary(for date: Date) async throws -> HKActivitySummary? {
        var components = Calendar.current.dateComponents([.calendar, .year, .month, .day], from: date)
        components.calendar = Calendar.current
        let predicate = HKQuery.predicateForActivitySummary(with: components)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: summaries?.first)
            }
            healthStore.execute(query)
        }
    }

    private func percent(current: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return Int((Double(current) / Double(goal) * 100).rounded())
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

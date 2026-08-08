import Foundation
import HealthKit

final class HealthKitStore {
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppModelError.healthDataUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: Self.readTypes) { success, error in
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

    func authorizationRequestStatus() async throws -> HKAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppModelError.healthDataUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: Self.readTypes) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }

    func recentReadableDataTypes() async throws -> [String] {
        let probes: [(HKSampleType, String)] = [
            (HKObjectType.quantityType(forIdentifier: .stepCount)!, "steps"),
            (HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!, "distance"),
            (HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, "move energy"),
            (HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!, "exercise minutes"),
            (HKObjectType.quantityType(forIdentifier: .heartRate)!, "heart rate"),
            (HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, "sleep"),
            (HKObjectType.workoutType(), "workouts"),
        ]

        var readableTypes: [String] = []
        for (sampleType, label) in probes {
            if try await hasRecentSamples(for: sampleType) {
                readableTypes.append(label)
            }
        }
        return readableTypes
    }

    private static let readTypes: Set<HKObjectType> = [
        HKObjectType.activitySummaryType(),
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType(),
    ]

    func installObservers(onUpdate: @escaping @Sendable () async -> Void) {
        guard observerQueries.isEmpty else { return }

        let sampleTypes: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
        ]

        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }

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
        let latestHeartRate = try await latestQuantity(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        let sleepHours = try await sleepHours(endingAt: now)
        let latestWorkout = try await latestWorkout(endingAt: now)

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
            standPercent: percent(current: standHours, goal: standGoal),
            latestHeartRateBPM: Int(latestHeartRate.rounded()),
            sleepHours: sleepHours,
            latestWorkout: latestWorkout
        )
    }

    private func latestQuantity(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(query)
        }
    }

    private func sleepHours(endingAt end: Date) async throws -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let startOfWindow = Calendar.current.date(byAdding: .hour, value: -12, to: end.startOfDay) ?? end.startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: startOfWindow, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let intervals = (samples as? [HKCategorySample] ?? []).compactMap { sample -> DateInterval? in
                    guard
                        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                        HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
                    else {
                        return nil
                    }

                    let clippedStart = max(sample.startDate, startOfWindow)
                    let clippedEnd = min(sample.endDate, end)
                    return clippedStart < clippedEnd
                        ? DateInterval(start: clippedStart, end: clippedEnd)
                        : nil
                }
                let seconds = Self.mergedDuration(of: intervals)
                continuation.resume(returning: seconds / 3600)
            }
            healthStore.execute(query)
        }
    }

    private static func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        intervals
            .sorted { $0.start < $1.start }
            .reduce(into: [DateInterval]()) { merged, interval in
                guard let last = merged.last, interval.start <= last.end else {
                    merged.append(interval)
                    return
                }

                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            }
            .reduce(0) { $0 + $1.duration }
    }

    private func latestWorkout(endingAt end: Date) async throws -> LatestWorkout? {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: nil)
                    return
                }

                let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let energy = workout.statistics(for: energyType)?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0

                continuation.resume(
                    returning: LatestWorkout(
                        activityType: workout.workoutActivityType.displayName,
                        startDate: workout.startDate,
                        durationSeconds: workout.duration,
                        totalEnergyBurnedKilocalories: energy
                    )
                )
            }
            healthStore.execute(query)
        }
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
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }
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
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: summaries?.first)
            }
            healthStore.execute(query)
        }
    }

    private func hasRecentSamples(for sampleType: HKSampleType) async throws -> Bool {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: false)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: !(samples?.isEmpty ?? true))
            }
            healthStore.execute(query)
        }
    }

    private static func isNoDataError(_ error: Error) -> Bool {
        guard let healthKitError = error as? HKError else {
            return false
        }
        return healthKitError.code == .errorNoData
    }

    private func percent(current: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return Int((Double(current) / Double(goal) * 100).rounded())
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .yoga:
            return "Yoga"
        case .hiking:
            return "Hiking"
        case .swimming:
            return "Swimming"
        case .elliptical:
            return "Elliptical"
        case .stairClimbing:
            return "Stair Climbing"
        case .rowing:
            return "Rowing"
        default:
            return "Workout"
        }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

import Foundation
import HealthKit

final class CalorieWidgetHealthReader: Sendable {
    static let shared = CalorieWidgetHealthReader()

    private let healthStore = HKHealthStore()
    private let store = CalorieWidgetStore.shared

    func fetchTodaySummary(now: Date = .now, calendar: Calendar = .current) async -> CalorieWidgetReadResult {
        let goal = store.dailyGoal
        let isConfigured = store.hasConnectedHealthKit

        guard HKHealthStore.isHealthDataAvailable(), isConfigured else {
            return CalorieWidgetReadResult(
                summary: store.cachedSummary(referenceDate: now, calendar: calendar),
                isConfigured: isConfigured
            )
        }

        let startOfDay = calendar.startOfDay(for: now)

        do {
            async let consumed = fetchCumulativeKilocalories(for: .dietaryEnergyConsumed, start: startOfDay, end: now)
            async let exercise = fetchCumulativeKilocalories(for: .activeEnergyBurned, start: startOfDay, end: now)

            let (consumedValue, exerciseValue) = try await (consumed, exercise)
            let snapshot = CalorieSnapshot(
                consumedCalories: consumedValue,
                exerciseCalories: exerciseValue,
                dayStart: startOfDay,
                updatedAt: now
            )
            store.saveSnapshot(snapshot)

            return CalorieWidgetReadResult(
                summary: CalorieSummary(
                    dailyGoal: goal,
                    consumedCalories: consumedValue,
                    exerciseCalories: exerciseValue
                ),
                isConfigured: true
            )
        } catch {
            // HealthKit is encrypted when the iPhone is locked (.errorDatabaseInaccessible).
            // Fall back to the latest App Group snapshot for today.
            return CalorieWidgetReadResult(
                summary: store.cachedSummary(referenceDate: now, calendar: calendar),
                isConfigured: true
            )
        }
    }

    private func fetchCumulativeKilocalories(
        for identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: predicate
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum
        )
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }
}

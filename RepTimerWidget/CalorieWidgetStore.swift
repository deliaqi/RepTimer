import Foundation
import HealthKit

enum CalorieSharedConfig {
    static let appGroupID = "group.com.colin.RepTimer.shared"
    static let widgetKind = "DailyCaloriesWidget"
    static let defaultDailyGoal: Double = 2000
    static let settingsDeepLinkURL = URL(string: "reptimer://calories-settings")
}

struct CalorieSummary: Equatable, Sendable {
    let dailyGoal: Double
    let consumedCalories: Double
    let exerciseCalories: Double

    /// Effective calorie budget for the day: daily goal plus active exercise calories burned.
    var effectiveBudget: Double {
        max(0, dailyGoal + exerciseCalories)
    }

    /// Remaining calories for the day: dailyGoal - consumedCalories + exerciseCalories.
    var remainingCalories: Double {
        dailyGoal - consumedCalories + exerciseCalories
    }

    var isOverBudget: Bool {
        remainingCalories < 0
    }

    var overageCalories: Double {
        max(0, -remainingCalories)
    }

    /// Rounded absolute calorie value shown in the center of the ring.
    var displayValue: Int {
        Int(abs(remainingCalories).rounded())
    }

    var statusLabel: String {
        isOverBudget ? "Over" : "Remaining"
    }

    /// Fraction of the effective budget consumed (clamped 0...1).
    var consumedFraction: Double {
        guard effectiveBudget > 0 else { return consumedCalories > 0 ? 1 : 0 }
        return min(1, max(0, consumedCalories / effectiveBudget))
    }

    /// Fraction of the effective budget coming from the base daily goal (clamped 0...1).
    /// Marks the ring boundary between the base goal allowance and calories added by activities.
    var goalBudgetFraction: Double {
        guard effectiveBudget > 0 else { return 1 }
        return min(1, max(0, dailyGoal / effectiveBudget))
    }

    /// Fraction of the effective budget added by active exercise calories (clamped 0...1).
    var exerciseBudgetFraction: Double {
        guard effectiveBudget > 0 else { return 0 }
        return min(1, max(0, exerciseCalories / effectiveBudget))
    }

    /// Fraction of the ring representing the over-budget excess (clamped 0...1).
    var overBudgetFraction: Double {
        guard isOverBudget else { return 0 }
        guard effectiveBudget > 0 else { return 1 }
        return min(1, max(0, overageCalories / effectiveBudget))
    }

    static let sampleRemaining = CalorieSummary(
        dailyGoal: 2000,
        consumedCalories: 1150,
        exerciseCalories: 350
    )

    static let sampleActivityOnlyRemaining = CalorieSummary(
        dailyGoal: 2000,
        consumedCalories: 2056,
        exerciseCalories: 300
    )

    static let sampleOver = CalorieSummary(
        dailyGoal: 2000,
        consumedCalories: 2547,
        exerciseCalories: 200
    )
}

struct CalorieSnapshot: Codable, Equatable, Sendable {
    let consumedCalories: Double
    let exerciseCalories: Double
    let dayStart: Date
    let updatedAt: Date
}

final class CalorieWidgetStore: Sendable {
    static let shared = CalorieWidgetStore()

    private enum Keys {
        static let dailyGoal = "calories.dailyGoal"
        static let snapshot = "calories.todaySnapshot"
        static let hasConnectedHealthKit = "calories.hasConnectedHealthKit"
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: CalorieSharedConfig.appGroupID) ?? .standard
    }

    var dailyGoal: Double {
        let stored = defaults().double(forKey: Keys.dailyGoal)
        return stored > 0 ? stored : CalorieSharedConfig.defaultDailyGoal
    }

    var hasConnectedHealthKit: Bool {
        defaults().bool(forKey: Keys.hasConnectedHealthKit)
    }

    func loadSnapshot(referenceDate: Date = .now, calendar: Calendar = .current) -> CalorieSnapshot? {
        guard let data = defaults().data(forKey: Keys.snapshot),
              let snapshot = try? JSONDecoder().decode(CalorieSnapshot.self, from: data) else {
            return nil
        }

        // Discard stale snapshots from previous days so midnight resets cleanly.
        guard calendar.isDate(snapshot.dayStart, inSameDayAs: referenceDate) else {
            return nil
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: CalorieSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults().set(data, forKey: Keys.snapshot)
    }

    func cachedSummary(referenceDate: Date = .now, calendar: Calendar = .current) -> CalorieSummary {
        let snapshot = loadSnapshot(referenceDate: referenceDate, calendar: calendar)
        return CalorieSummary(
            dailyGoal: dailyGoal,
            consumedCalories: snapshot?.consumedCalories ?? 0,
            exerciseCalories: snapshot?.exerciseCalories ?? 0
        )
    }
}

struct CalorieWidgetReadResult: Sendable {
    let summary: CalorieSummary
    let isConfigured: Bool
}

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

import Foundation
import HealthKit
import Observation
import WidgetKit

enum CalorieSharedConfig {
    static let appGroupID = "group.com.colin.RepTimer.shared"
    static let widgetKind = "DailyCaloriesWidget"
    static let defaultDailyGoal: Double = 2000
    static let minDailyGoal: Double = 500
    static let maxDailyGoal: Double = 10000
    static let settingsDeepLinkScheme = "reptimer"
    static let settingsDeepLinkHost = "calories-settings"

    static var settingsDeepLinkURL: URL? {
        URL(string: "\(settingsDeepLinkScheme)://\(settingsDeepLinkHost)")
    }
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
}

struct CalorieSnapshot: Codable, Equatable, Sendable {
    let consumedCalories: Double
    let exerciseCalories: Double
    let dayStart: Date
    let updatedAt: Date
}

final class CalorieStore: Sendable {
    static let shared = CalorieStore()

    private enum Keys {
        static let dailyGoal = "calories.dailyGoal"
        static let snapshot = "calories.todaySnapshot"
        static let hasConnectedHealthKit = "calories.hasConnectedHealthKit"
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: CalorieSharedConfig.appGroupID) ?? .standard
    }

    var dailyGoal: Double {
        get {
            let stored = defaults().double(forKey: Keys.dailyGoal)
            return stored > 0 ? stored : CalorieSharedConfig.defaultDailyGoal
        }
        set {
            let clamped = min(CalorieSharedConfig.maxDailyGoal, max(CalorieSharedConfig.minDailyGoal, newValue))
            defaults().set(clamped, forKey: Keys.dailyGoal)
        }
    }

    var hasConnectedHealthKit: Bool {
        get { defaults().bool(forKey: Keys.hasConnectedHealthKit) }
        set { defaults().set(newValue, forKey: Keys.hasConnectedHealthKit) }
    }

    func loadSnapshot(referenceDate: Date = .now, calendar: Calendar = .current) -> CalorieSnapshot? {
        guard let data = defaults().data(forKey: Keys.snapshot),
              let snapshot = try? JSONDecoder().decode(CalorieSnapshot.self, from: data) else {
            return nil
        }

        // Discard snapshots from previous calendar days so midnight resets cleanly.
        guard calendar.isDate(snapshot.dayStart, inSameDayAs: referenceDate) else {
            return nil
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: CalorieSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults().set(data, forKey: Keys.snapshot)
    }

    func todaySummary(referenceDate: Date = .now, calendar: Calendar = .current) -> CalorieSummary {
        let snapshot = loadSnapshot(referenceDate: referenceDate, calendar: calendar)
        return CalorieSummary(
            dailyGoal: dailyGoal,
            consumedCalories: snapshot?.consumedCalories ?? 0,
            exerciseCalories: snapshot?.exerciseCalories ?? 0
        )
    }

    func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: CalorieSharedConfig.widgetKind)
    }
}

@MainActor
@Observable
final class CalorieHealthManager {
    static let shared = CalorieHealthManager()

    private let healthStore = HKHealthStore()
    private let store = CalorieStore.shared
    private var activeObserverQueries: [HKObserverQuery] = []

    var dailyGoal: Double
    var todaySummary: CalorieSummary
    var hasConnectedHealthKit: Bool
    var isSyncing = false
    var lastUpdated: Date?
    var errorMessage: String?

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    private init() {
        let initialGoal = store.dailyGoal
        let snapshot = store.loadSnapshot()
        dailyGoal = initialGoal
        hasConnectedHealthKit = store.hasConnectedHealthKit
        lastUpdated = snapshot?.updatedAt
        todaySummary = CalorieSummary(
            dailyGoal: initialGoal,
            consumedCalories: snapshot?.consumedCalories ?? 0,
            exerciseCalories: snapshot?.exerciseCalories ?? 0
        )
    }

    func updateDailyGoal(_ newGoal: Double) {
        let clamped = min(CalorieSharedConfig.maxDailyGoal, max(CalorieSharedConfig.minDailyGoal, newGoal.rounded()))
        store.dailyGoal = clamped
        dailyGoal = clamped
        todaySummary = CalorieSummary(
            dailyGoal: clamped,
            consumedCalories: todaySummary.consumedCalories,
            exerciseCalories: todaySummary.exerciseCalories
        )
        store.reloadWidget()
    }

    func requestAuthorizationAndSync() async {
        guard isHealthDataAvailable else {
            errorMessage = "Apple Health is not available on this device."
            return
        }

        errorMessage = nil
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            store.hasConnectedHealthKit = true
            hasConnectedHealthKit = true
            registerBackgroundObserversIfNeeded()
            await refreshTodayCalories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppBecameActive() async {
        dailyGoal = store.dailyGoal
        hasConnectedHealthKit = store.hasConnectedHealthKit

        guard isHealthDataAvailable, hasConnectedHealthKit else {
            todaySummary = store.todaySummary()
            return
        }

        registerBackgroundObserversIfNeeded()
        await refreshTodayCalories()
    }

    func refreshTodayCalories() async {
        guard isHealthDataAvailable else { return }

        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)

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
            lastUpdated = now
            todaySummary = CalorieSummary(
                dailyGoal: store.dailyGoal,
                consumedCalories: consumedValue,
                exerciseCalories: exerciseValue
            )
            store.reloadWidget()
        } catch let hkError as HKError where hkError.code == .errorDatabaseInaccessible {
            // Device locked while syncing in background; keep cached summary intact.
            todaySummary = store.todaySummary(referenceDate: now)
        } catch {
            errorMessage = error.localizedDescription
            todaySummary = store.todaySummary(referenceDate: now)
        }
    }

    /// Registers HealthKit observer queries synchronously so cold background launches from
    /// HealthKit Background Delivery immediately receive pending sample updates.
    func registerBackgroundObserversIfNeeded() {
        hasConnectedHealthKit = store.hasConnectedHealthKit
        guard isHealthDataAvailable, hasConnectedHealthKit, activeObserverQueries.isEmpty else { return }

        let sampleTypes: [HKQuantityType] = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.activeEnergyBurned)
        ]

        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }

                Task { @MainActor in
                    await CalorieHealthManager.shared.refreshTodayCalories()
                    completionHandler()
                }
            }

            healthStore.execute(query)
            activeObserverQueries.append(query)

            Task {
                do {
                    try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
                } catch {
                    // Background delivery is unavailable on Simulator; foreground and widget refreshes still operate.
                }
            }
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

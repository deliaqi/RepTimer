import Foundation
import HealthKit
import Observation

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
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal)
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
        await requestNewlyAddedReadTypesIfNeeded()
        await refreshTodayCalories()
    }

    /// Prompts users who connected Apple Health before macro tracking existed to grant the new
    /// protein / carbs / fat read types. HealthKit only reports `.shouldRequest` for undetermined types.
    private func requestNewlyAddedReadTypesIfNeeded() async {
        guard let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: readTypes),
              status == .shouldRequest else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func refreshTodayCalories() async {
        guard isHealthDataAvailable else { return }

        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)

        do {
            async let consumed = fetchCumulativeSum(for: .dietaryEnergyConsumed, unit: .kilocalorie(), start: startOfDay, end: now)
            async let exercise = fetchCumulativeSum(for: .activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: now)
            async let protein = fetchCumulativeSum(for: .dietaryProtein, unit: .gram(), start: startOfDay, end: now)
            async let carbs = fetchCumulativeSum(for: .dietaryCarbohydrates, unit: .gram(), start: startOfDay, end: now)
            async let fat = fetchCumulativeSum(for: .dietaryFatTotal, unit: .gram(), start: startOfDay, end: now)

            let (consumedValue, exerciseValue) = try await (consumed, exercise)
            let (proteinValue, carbsValue, fatValue) = try await (protein, carbs, fat)
            let snapshot = CalorieSnapshot(
                consumedCalories: consumedValue,
                exerciseCalories: exerciseValue,
                dayStart: startOfDay,
                updatedAt: now,
                proteinGrams: proteinValue,
                carbsGrams: carbsValue,
                fatGrams: fatValue
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

    private func fetchCumulativeSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
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
        return statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }
}

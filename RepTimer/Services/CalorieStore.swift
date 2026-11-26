import Foundation
import WidgetKit

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

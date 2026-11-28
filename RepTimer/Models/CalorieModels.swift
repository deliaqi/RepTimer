import Foundation

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
    // Macro grams shared with the medium widget. Optional so older snapshots still decode.
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
}

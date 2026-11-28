import Foundation

enum CalorieSharedConfig {
    static let appGroupID = "group.com.colin.RepTimer.shared"
    static let widgetKind = "DailyCaloriesWidget"
    static let defaultDailyGoal: Double = 2000
    static let settingsDeepLinkURL = URL(string: "reptimer://calories-settings")
}

/// Macronutrient categories tracked by the medium calorie widget.
enum MacroKind: CaseIterable, Sendable {
    case protein
    case carbs
    case fat

    var title: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    /// Energy density used to convert a calorie share into grams.
    var kilocaloriesPerGram: Double {
        switch self {
        case .protein, .carbs: 4
        case .fat: 9
        }
    }

    /// Recommended share of the total daily calorie goal (30% protein / 40% carbs / 30% fat).
    var recommendedCalorieShare: Double {
        switch self {
        case .protein: 0.30
        case .carbs: 0.40
        case .fat: 0.30
        }
    }
}

/// Grams of each macronutrient consumed today.
struct MacroNutrients: Equatable, Sendable {
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    static let zero = MacroNutrients(proteinGrams: 0, carbsGrams: 0, fatGrams: 0)

    func grams(for kind: MacroKind) -> Double {
        switch kind {
        case .protein: proteinGrams
        case .carbs: carbsGrams
        case .fat: fatGrams
        }
    }
}

/// Consumed vs. recommended grams for a single macronutrient.
struct MacroProgress: Identifiable, Sendable {
    let kind: MacroKind
    let consumedGrams: Double
    let recommendedGrams: Double

    var id: MacroKind { kind }

    /// Unclamped fraction of the recommended intake (may exceed 1).
    var fraction: Double {
        guard recommendedGrams > 0 else { return consumedGrams > 0 ? 1 : 0 }
        return max(0, consumedGrams / recommendedGrams)
    }

    var percentage: Int {
        Int((fraction * 100).rounded())
    }
}

struct CalorieSummary: Equatable, Sendable {
    let dailyGoal: Double
    let consumedCalories: Double
    let exerciseCalories: Double
    var macros: MacroNutrients = .zero

    /// Recommended grams of a macronutrient, derived from the base daily calorie goal.
    func recommendedGrams(for kind: MacroKind) -> Double {
        max(0, dailyGoal) * kind.recommendedCalorieShare / kind.kilocaloriesPerGram
    }

    var macroProgress: [MacroProgress] {
        MacroKind.allCases.map { kind in
            MacroProgress(
                kind: kind,
                consumedGrams: macros.grams(for: kind),
                recommendedGrams: recommendedGrams(for: kind)
            )
        }
    }

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
        exerciseCalories: 350,
        macros: MacroNutrients(proteinGrams: 72, carbsGrams: 128, fatGrams: 38)
    )

    static let sampleActivityOnlyRemaining = CalorieSummary(
        dailyGoal: 2000,
        consumedCalories: 2056,
        exerciseCalories: 300,
        macros: MacroNutrients(proteinGrams: 128, carbsGrams: 230, fatGrams: 70)
    )

    static let sampleOver = CalorieSummary(
        dailyGoal: 2000,
        consumedCalories: 2547,
        exerciseCalories: 200,
        macros: MacroNutrients(proteinGrams: 142, carbsGrams: 290, fatGrams: 92)
    )
}

struct CalorieSnapshot: Codable, Equatable, Sendable {
    let consumedCalories: Double
    let exerciseCalories: Double
    let dayStart: Date
    let updatedAt: Date
    // Optional so snapshots written before macro tracking still decode.
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?

    var macros: MacroNutrients {
        MacroNutrients(
            proteinGrams: proteinGrams ?? 0,
            carbsGrams: carbsGrams ?? 0,
            fatGrams: fatGrams ?? 0
        )
    }
}

struct CalorieWidgetReadResult: Sendable {
    let summary: CalorieSummary
    let isConfigured: Bool
}

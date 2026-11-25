import SwiftUI
import WidgetKit

struct CalorieWidgetEntry: TimelineEntry {
    let date: Date
    let summary: CalorieSummary
    let isConfigured: Bool
    let isPlaceholder: Bool

    static let sampleRemaining = CalorieWidgetEntry(
        date: .now,
        summary: .sampleRemaining,
        isConfigured: true,
        isPlaceholder: false
    )

    static let sampleOver = CalorieWidgetEntry(
        date: .now,
        summary: .sampleOver,
        isConfigured: true,
        isPlaceholder: false
    )
}

struct CalorieTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieWidgetEntry {
        CalorieWidgetEntry(
            date: .now,
            summary: .sampleRemaining,
            isConfigured: true,
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.sampleRemaining)
            return
        }

        Task {
            let result = await CalorieWidgetHealthReader.shared.fetchTodaySummary()
            completion(
                CalorieWidgetEntry(
                    date: .now,
                    summary: result.summary,
                    isConfigured: result.isConfigured,
                    isPlaceholder: false
                )
            )
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieWidgetEntry>) -> Void) {
        Task {
            let now = Date.now
            let calendar = Calendar.current
            let result = await CalorieWidgetHealthReader.shared.fetchTodaySummary(now: now, calendar: calendar)

            let currentEntry = CalorieWidgetEntry(
                date: now,
                summary: result.summary,
                isConfigured: result.isConfigured,
                isPlaceholder: false
            )

            var entries: [CalorieWidgetEntry] = [currentEntry]

            // Add a midnight reset entry so the ring resets automatically at 00:00 even before HealthKit wakes up.
            let startOfToday = calendar.startOfDay(for: now)
            if let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) {
                let resetSummary = CalorieSummary(
                    dailyGoal: result.summary.dailyGoal,
                    consumedCalories: 0,
                    exerciseCalories: 0
                )
                entries.append(
                    CalorieWidgetEntry(
                        date: nextMidnight,
                        summary: resetSummary,
                        isConfigured: result.isConfigured,
                        isPlaceholder: false
                    )
                )
            }

            let periodicRefresh = calendar.date(byAdding: .minute, value: 20, to: now) ?? now.addingTimeInterval(1200)
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? periodicRefresh
            let reloadDate = min(periodicRefresh, nextMidnight)

            completion(Timeline(entries: entries, policy: .after(reloadDate)))
        }
    }
}

struct DailyCaloriesWidget: Widget {
    let kind = CalorieSharedConfig.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieTimelineProvider()) { entry in
            DailyCaloriesWidgetContainerView(entry: entry)
        }
        .configurationDisplayName("Daily Calories")
        .description("Track consumed and remaining calories for the day from Apple Health.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private struct DailyCaloriesWidgetContainerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CalorieWidgetEntry

    var body: some View {
        CalorieWidgetView(entry: entry)
            .widgetURL(CalorieSharedConfig.settingsDeepLinkURL)
            .containerBackground(for: .widget) {
                if colorScheme == .dark {
                    Color(red: 0.08, green: 0.09, blue: 0.10)
                } else {
                    Color.white
                }
            }
    }
}

// MARK: - Previews

#Preview("Small - Remaining & Over", as: .systemSmall) {
    DailyCaloriesWidget()
} timeline: {
    CalorieWidgetEntry.sampleRemaining
    CalorieWidgetEntry.sampleOver
}

#Preview("Small - Unconfigured", as: .systemSmall) {
    DailyCaloriesWidget()
} timeline: {
    CalorieWidgetEntry(
        date: .now,
        summary: CalorieSummary(dailyGoal: 2000, consumedCalories: 0, exerciseCalories: 0),
        isConfigured: false,
        isPlaceholder: false
    )
}

#Preview("Lock Screen - Circular", as: .accessoryCircular) {
    DailyCaloriesWidget()
} timeline: {
    CalorieWidgetEntry.sampleRemaining
    CalorieWidgetEntry.sampleOver
}

#Preview("Lock Screen - Rectangular", as: .accessoryRectangular) {
    DailyCaloriesWidget()
} timeline: {
    CalorieWidgetEntry.sampleRemaining
    CalorieWidgetEntry.sampleOver
}

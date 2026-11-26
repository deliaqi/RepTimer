import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityManager {
    private var currentActivity: Activity<RepTimerActivityAttributes>?

    func start(rounds: Int, state: RepTimerActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let oldActivities = Activity<RepTimerActivityAttributes>.activities
        currentActivity = nil
        for activity in oldActivities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = RepTimerActivityAttributes(totalRounds: rounds)
        let content = ActivityContent(state: state, staleDate: state.endDate)
        currentActivity = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func update(state: RepTimerActivityAttributes.ContentState) {
        guard let activity = currentActivity ?? Activity<RepTimerActivityAttributes>.activities.first else {
            return
        }
        currentActivity = activity
        let content = ActivityContent(state: state, staleDate: state.endDate)
        Task {
            await activity.update(content)
        }
    }

    func end() {
        let activitiesToEnd = Activity<RepTimerActivityAttributes>.activities
        let tracked = currentActivity
        currentActivity = nil
        Task {
            if let tracked {
                await tracked.end(nil, dismissalPolicy: .immediate)
            }
            for activity in activitiesToEnd where activity.id != tracked?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

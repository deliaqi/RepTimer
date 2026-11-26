import ActivityKit
import Foundation

struct RepTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseRawValue: String
        var phaseTitle: String
        var currentRound: Int
        var totalRounds: Int
        var remainingSeconds: Int
        var phaseDuration: Int
        var endDate: Date?
        var isRunning: Bool
        var isComplete: Bool
        var nextPhaseTitle: String?
        var nextPhaseSeconds: Int?
    }

    var totalRounds: Int
}

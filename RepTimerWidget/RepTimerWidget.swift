import ActivityKit
import SwiftUI
import WidgetKit

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

struct RepTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepTimerActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color(red: 0.09, green: 0.10, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let accent = phaseAccentColor(for: state.phaseRawValue)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: phaseSymbol(for: state))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accent)
                        Text(state.isComplete ? "DONE" : state.phaseRawValue)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(accent)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.isRunning ? "ROUND \(state.currentRound)/\(state.totalRounds)" : (state.isComplete ? "COMPLETE" : "PAUSED · \(state.currentRound)/\(state.totalRounds)"))
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            countdownText(for: state)
                                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)

                            Spacer()

                            if state.isComplete {
                                Text("Workout finished")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            } else if let nextTitle = state.nextPhaseTitle, let nextSeconds = state.nextPhaseSeconds {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("UP NEXT")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .tracking(1)
                                        .foregroundStyle(.white.opacity(0.45))
                                    Text("\(nextTitle) · \(formatClock(nextSeconds))")
                                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            } else {
                                Text("FINAL SET")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }

                        phaseProgressBar(for: state, tint: accent)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: phaseSymbol(for: state))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .accessibilityLabel(state.phaseTitle)
            } compactTrailing: {
                Group {
                    if state.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                    } else if state.isRunning, let endDate = state.endDate {
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .foregroundStyle(.white)
                            .frame(maxWidth: 52, alignment: .trailing)
                    } else {
                        Text(formatClock(state.remainingSeconds))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: 52, alignment: .trailing)
                    }
                }
            } minimal: {
                minimalCountdownView(for: state, tint: accent)
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let state: RepTimerActivityAttributes.ContentState

    var body: some View {
        let accent = phaseAccentColor(for: state.phaseRawValue)

        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: phaseSymbol(for: state))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                    Text(state.isComplete ? "WORKOUT COMPLETE" : state.phaseRawValue)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(accent)
                }

                Spacer()

                Text(state.isRunning ? "ROUND \(state.currentRound) / \(state.totalRounds)" : (state.isComplete ? "DONE" : "PAUSED · \(state.currentRound) / \(state.totalRounds)"))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.1), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline) {
                countdownText(for: state)
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)

                Spacer()

                if state.isComplete {
                    Text("\(state.totalRounds) rounds completed")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                } else if let nextTitle = state.nextPhaseTitle, let nextSeconds = state.nextPhaseSeconds {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("UP NEXT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.45))
                        Text("\(nextTitle) · \(formatClock(nextSeconds))")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                } else {
                    Text("FINAL SET · FINISH STRONG")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            phaseProgressBar(for: state, tint: accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

@ViewBuilder
private func minimalCountdownView(for state: RepTimerActivityAttributes.ContentState, tint: Color) -> some View {
    if state.isComplete {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tint)
            .frame(maxWidth: 28, maxHeight: 28)
            .accessibilityLabel("Workout complete")
    } else if state.isRunning, let endDate = state.endDate {
        let startDate = endDate.addingTimeInterval(-TimeInterval(max(1, state.phaseDuration)))
        ProgressView(timerInterval: startDate...endDate, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(tint)
        .frame(maxWidth: 28, maxHeight: 28)
        .accessibilityLabel("\(state.phaseTitle), round \(state.currentRound) of \(state.totalRounds)")
    } else {
        let total = Double(max(1, state.phaseDuration))
        let remaining = Double(max(0, min(state.phaseDuration, state.remainingSeconds)))
        ProgressView(value: remaining, total: total) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(tint)
        .frame(maxWidth: 28, maxHeight: 28)
        .accessibilityLabel("Paused, \(state.phaseTitle), \(formatClock(state.remainingSeconds)) remaining")
    }
}

@ViewBuilder
private func countdownText(for state: RepTimerActivityAttributes.ContentState) -> some View {
    if state.isComplete {
        Text("Done")
    } else if state.isRunning, let endDate = state.endDate {
        Text(timerInterval: Date.now...endDate, countsDown: true)
    } else {
        Text(formatClock(state.remainingSeconds))
    }
}

@ViewBuilder
private func phaseProgressBar(for state: RepTimerActivityAttributes.ContentState, tint: Color) -> some View {
    if state.isComplete {
        ProgressView(value: 1.0)
            .tint(tint)
    } else if state.isRunning, let endDate = state.endDate {
        let startDate = endDate.addingTimeInterval(-TimeInterval(max(1, state.phaseDuration)))
        ProgressView(timerInterval: startDate...endDate, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(tint)
    } else {
        let total = Double(max(1, state.phaseDuration))
        let elapsed = max(0, min(total, total - Double(state.remainingSeconds)))
        ProgressView(value: elapsed, total: total)
            .tint(tint)
    }
}

private func phaseAccentColor(for phaseRawValue: String) -> Color {
    switch phaseRawValue {
    case "PREP":
        Color(red: 0.725, green: 0.910, blue: 0.871)
    case "REST":
        Color(red: 0.714, green: 0.867, blue: 0.725)
    case "COOLDOWN":
        Color(red: 0.549, green: 0.812, blue: 0.769)
    default:
        Color(red: 0.847, green: 1.0, blue: 0.333)
    }
}

private func phaseSymbol(for state: RepTimerActivityAttributes.ContentState) -> String {
    if state.isComplete { return "checkmark.circle.fill" }
    switch state.phaseRawValue {
    case "PREP": return "timer"
    case "WORK": return "dumbbell.fill"
    case "REST": return "wind"
    case "COOLDOWN": return "figure.cooldown"
    default: return "stopwatch.fill"
    }
}

private func formatClock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

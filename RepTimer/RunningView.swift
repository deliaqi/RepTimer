import SwiftUI

struct RunningView: View {
    @ObservedObject var workout: WorkoutTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TempoPalette.runningBackground.ignoresSafeArea()
            Circle()
                .fill(TempoPalette.forest.opacity(0.35))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 170, y: -300)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 24)
                if workout.isComplete {
                    completionContent
                } else {
                    timerContent
                }
                Spacer(minLength: 26)
                controls
            }
            .padding(.horizontal, 24)
            .padding(.top, 15)
            .padding(.bottom, 20)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: workout.phase)
    }

    private var topBar: some View {
        HStack {
            Button {
                workout.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 42, height: 42)
                    .tempoGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End workout")
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(TempoPalette.lime).frame(width: 6, height: 6)
                Text("TEMPO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Text("\(workout.currentRound) / \(workout.rounds)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 54, height: 34)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    private var timerContent: some View {
        VStack(spacing: 25) {
            VStack(spacing: 8) {
                Text(workout.phase.rawValue)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(phaseAccent)
                Text(phasePrompt)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 11)
                TimelineView(.animation(
                    minimumInterval: reduceMotion ? 1 : 1.0 / 30.0,
                    paused: !workout.isRunning
                )) { timeline in
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, workout.progress(at: timeline.date))))
                        .stroke(phaseAccent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: phaseAccent.opacity(0.2), radius: 12)
                }
                VStack(spacing: 0) {
                    Text(clockString(workout.remainingSeconds))
                        .font(.system(size: 68, weight: .medium, design: .rounded).monospacedDigit())
                        .tracking(-2.5)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: workout.remainingSeconds)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("REMAINING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(.top, 4)
                }
            }
            .frame(width: 276, height: 276)

            HStack(spacing: 8) {
                ForEach(1...workout.rounds, id: \.self) { round in
                    Capsule()
                        .fill(round < workout.currentRound ? TempoPalette.lime : round == workout.currentRound ? .white : .white.opacity(0.14))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 15)

            if let next = workout.nextInterval {
                HStack(spacing: 11) {
                    Image(systemName: next.0 == .work ? "dumbbell.fill" : "wind")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TempoPalette.lime)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.0 == .cooldown ? "UP NEXT · COOLDOWN" : "UP NEXT · ROUND \(next.2)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.43))
                        Text("\(next.0.title) · \(clockString(next.1))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(13)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            } else {
                Text(workout.phase == .cooldown ? "COOLDOWN · FINISH STRONG" : "FINAL SET · FINISH STRONG")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
            }
        }
    }

    private var completionContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(TempoPalette.lime).frame(width: 94, height: 94)
                Image(systemName: "checkmark")
                    .font(.system(size: 37, weight: .bold))
                    .foregroundStyle(TempoPalette.accentInk)
            }
            VStack(spacing: 8) {
                Text("WORKOUT\nCOMPLETE")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("That’s another one in the books.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            HStack(spacing: 28) {
                stat(value: "\(workout.rounds)", label: "ROUNDS")
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 35)
                stat(value: clockString(workout.totalWorkoutSeconds), label: "SESSION")
            }
            .padding(.top, 9)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        Group {
            if workout.isComplete {
                Button {
                    workout.stop()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(TempoPalette.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 13) {
                    Button {
                        workout.pauseOrResume()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: workout.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(workout.isRunning ? "Pause" : "Resume")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(TempoPalette.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        workout.skipInterval()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 56)
                            .tempoGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip interval")
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var phaseAccent: Color {
        switch workout.phase {
        case .preparation: TempoPalette.preparation
        case .work: TempoPalette.lime
        case .rest: TempoPalette.rest
        case .cooldown: TempoPalette.teal
        }
    }

    private var phasePrompt: String {
        switch workout.phase {
        case .preparation: "Get set. Your first work interval is next."
        case .work: "Give this set your focus."
        case .rest: "Breathe. You’ve earned it."
        case .cooldown: "Ease down. Take a moment to recover."
        }
    }
}

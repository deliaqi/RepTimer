import Combine
import Foundation

@MainActor
final class WorkoutTimer: ObservableObject {
    @Published var workSeconds = 60
    @Published var restSeconds = 120
    @Published var preparationSeconds = 10
    @Published var preparationEnabled = false
    @Published var cooldownSeconds = 60
    @Published var cooldownEnabled = false
    @Published var rounds = 4
    @Published private(set) var phase: WorkoutPhase = .work
    @Published private(set) var currentRound = 1
    @Published private(set) var remainingSeconds = 60
    @Published private(set) var isRunning = false
    @Published private(set) var isActive = false
    @Published private(set) var isComplete = false

    private let soundPlayer = CountdownSoundPlayer()
    private let liveActivityManager = WorkoutLiveActivityManager()
    private var endDate: Date?
    private var pausedRemainingTime: TimeInterval?
    private var lastBeepedSecond: Int?
    private var timer: AnyCancellable?

    var phaseDuration: Int {
        switch phase {
        case .preparation: preparationSeconds
        case .work: workSeconds
        case .rest: restSeconds
        case .cooldown: cooldownSeconds
        }
    }

    func progress(at date: Date) -> Double {
        guard phaseDuration > 0 else { return 0 }
        let remainingTime: TimeInterval
        if isRunning {
            remainingTime = endDate?.timeIntervalSince(date) ?? TimeInterval(remainingSeconds)
        } else {
            remainingTime = pausedRemainingTime ?? TimeInterval(remainingSeconds)
        }
        return min(1, max(0, 1 - remainingTime / TimeInterval(phaseDuration)))
    }

    var totalWorkoutSeconds: Int {
        workSeconds * rounds
            + restSeconds * max(0, rounds - 1)
            + (preparationEnabled ? preparationSeconds : 0)
            + (cooldownEnabled ? cooldownSeconds : 0)
    }

    var nextInterval: (WorkoutPhase, Int, Int)? {
        if phase == .preparation {
            return (.work, workSeconds, currentRound)
        }
        if phase == .work {
            if currentRound < rounds {
                return (.rest, restSeconds, currentRound)
            }
            guard cooldownEnabled else { return nil }
            return (.cooldown, cooldownSeconds, currentRound)
        }
        if phase == .rest {
            return (.work, workSeconds, min(currentRound + 1, rounds))
        }
        return nil
    }

    init(preset: TimerPreset? = nil) {
        if let preset {
            apply(preset)
        }
        timer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshCountdown()
            }
    }

    func apply(_ preset: TimerPreset) {
        apply(
            work: preset.work,
            rest: preset.rest,
            rounds: preset.rounds,
            preparationSeconds: preset.preparationSeconds,
            preparationEnabled: preset.preparationEnabled,
            cooldownSeconds: preset.cooldownSeconds,
            cooldownEnabled: preset.cooldownEnabled
        )
    }

    func apply(
        work: Int,
        rest: Int,
        rounds: Int,
        preparationSeconds: Int? = nil,
        preparationEnabled: Bool? = nil,
        cooldownSeconds: Int? = nil,
        cooldownEnabled: Bool? = nil
    ) {
        guard !isActive else { return }
        workSeconds = work
        restSeconds = rest
        if let preparationSeconds { self.preparationSeconds = preparationSeconds }
        if let preparationEnabled { self.preparationEnabled = preparationEnabled }
        if let cooldownSeconds { self.cooldownSeconds = cooldownSeconds }
        if let cooldownEnabled { self.cooldownEnabled = cooldownEnabled }
        self.rounds = rounds
        resetState()
    }

    func start() {
        if isComplete { resetState() }
        isActive = true
        isRunning = true
        pausedRemainingTime = nil
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        triggerCountdownBeepIfNeeded(for: remainingSeconds)
        liveActivityManager.start(rounds: rounds, state: currentActivityState)
    }

    func pauseOrResume() {
        guard isActive, !isComplete else { return }
        if isRunning {
            refreshCountdown()
            guard !isComplete else { return }
            pausedRemainingTime = max(0, endDate?.timeIntervalSinceNow ?? TimeInterval(remainingSeconds))
            isRunning = false
            endDate = nil
        } else {
            isRunning = true
            endDate = Date().addingTimeInterval(pausedRemainingTime ?? TimeInterval(remainingSeconds))
            pausedRemainingTime = nil
        }
        liveActivityManager.update(state: currentActivityState)
    }

    func skipInterval() {
        guard isActive, !isComplete else { return }
        advanceInterval()
    }

    func stop() {
        liveActivityManager.end()
        resetState()
    }

    private func refreshCountdown() {
        guard isRunning, let endDate else { return }
        let seconds = Int(ceil(endDate.timeIntervalSinceNow))
        if seconds <= 0 {
            soundPlayer.playTransitionTone()
            advanceInterval(suppressInitialBeep: true)
        } else {
            remainingSeconds = seconds
            triggerCountdownBeepIfNeeded(for: seconds)
        }
    }

    private func triggerCountdownBeepIfNeeded(for seconds: Int) {
        guard (1...3).contains(seconds), lastBeepedSecond != seconds else { return }
        lastBeepedSecond = seconds
        soundPlayer.playCountdownBeep()
    }

    private func advanceInterval(suppressInitialBeep: Bool = false) {
        switch phase {
        case .preparation:
            phase = .work
        case .work:
            if currentRound < rounds {
                phase = .rest
            } else if cooldownEnabled {
                phase = .cooldown
            } else {
                finish()
                return
            }
        case .rest:
            currentRound += 1
            phase = .work
        case .cooldown:
            finish()
            return
        }
        remainingSeconds = phaseDuration
        pausedRemainingTime = nil
        lastBeepedSecond = suppressInitialBeep && (1...3).contains(remainingSeconds) ? remainingSeconds : nil
        endDate = isRunning ? Date().addingTimeInterval(TimeInterval(remainingSeconds)) : nil
        liveActivityManager.update(state: currentActivityState)
    }

    private func finish() {
        isComplete = true
        isActive = true
        isRunning = false
        remainingSeconds = 0
        endDate = nil
        pausedRemainingTime = nil
        lastBeepedSecond = nil
        liveActivityManager.update(state: currentActivityState)
    }

    private func resetState() {
        phase = preparationEnabled ? .preparation : .work
        currentRound = 1
        remainingSeconds = phaseDuration
        isRunning = false
        isActive = false
        isComplete = false
        endDate = nil
        pausedRemainingTime = nil
        lastBeepedSecond = nil
    }

    private var currentActivityState: RepTimerActivityAttributes.ContentState {
        let next = nextInterval
        return RepTimerActivityAttributes.ContentState(
            phaseRawValue: phase.rawValue,
            phaseTitle: phase.title,
            currentRound: currentRound,
            totalRounds: rounds,
            remainingSeconds: remainingSeconds,
            phaseDuration: phaseDuration,
            endDate: endDate,
            isRunning: isRunning,
            isComplete: isComplete,
            nextPhaseTitle: next?.0.title,
            nextPhaseSeconds: next?.1
        )
    }
}

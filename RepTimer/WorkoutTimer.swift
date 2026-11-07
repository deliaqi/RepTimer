import ActivityKit
import AVFoundation
import Combine
import Foundation

enum WorkoutPhase: String {
    case preparation = "PREP"
    case work = "WORK"
    case rest = "REST"
    case cooldown = "COOLDOWN"

    var title: String {
        switch self {
        case .preparation: "Get ready"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }
}

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

final class CountdownSoundPlayer: @unchecked Sendable {
    static let settingsKey = "tempo.countdownSound"

    private let audioQueue = DispatchQueue(label: "com.codex.Tempo.countdownAudio", qos: .userInteractive)
    private var countdownPlayer: AVAudioPlayer?
    private var transitionPlayer: AVAudioPlayer?

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.settingsKey) as? Bool ?? true
    }

    init() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            self.countdownPlayer = Self.makePlayer(frequency: 880, duration: 0.11, amplitude: 0.35, releaseDuration: 0.03)
            self.transitionPlayer = Self.makePlayer(frequency: 1318.5, duration: 0.26, amplitude: 0.42, releaseDuration: 0.06)
        }
    }

    func playCountdownBeep() {
        guard isEnabled else { return }
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.play(self.countdownPlayer)
        }
    }

    func playTransitionTone() {
        guard isEnabled else { return }
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.play(self.transitionPlayer)
        }
    }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if player.isPlaying {
            player.currentTime = 0
        } else {
            player.play()
        }
    }

    private static func makePlayer(
        frequency: Double,
        duration: Double,
        amplitude: Double,
        releaseDuration: Double
    ) -> AVAudioPlayer? {
        let wavData = makeWAVData(
            frequency: frequency,
            duration: duration,
            amplitude: amplitude,
            releaseDuration: releaseDuration
        )
        let player = try? AVAudioPlayer(data: wavData)
        player?.prepareToPlay()
        return player
    }

    private static func makeWAVData(
        frequency: Double,
        duration: Double,
        amplitude: Double,
        releaseDuration: Double
    ) -> Data {
        let sampleRate = 44_100
        let frameCount = max(1, Int(Double(sampleRate) * duration))
        let attackFrames = max(1, Int(Double(sampleRate) * 0.008))
        let releaseFrames = max(1, Int(Double(sampleRate) * releaseDuration))
        let dataByteCount = frameCount * MemoryLayout<Int16>.size

        var data = Data(capacity: 44 + dataByteCount)
        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(UInt32(36 + dataByteCount))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(UInt32(dataByteCount))

        for frame in 0..<frameCount {
            let attackEnvelope = min(1.0, Double(frame) / Double(attackFrames))
            let framesRemaining = frameCount - 1 - frame
            let releaseEnvelope = min(1.0, Double(framesRemaining) / Double(releaseFrames))
            let envelope = min(attackEnvelope, releaseEnvelope)

            let angle = 2.0 * Double.pi * frequency * Double(frame) / Double(sampleRate)
            let sampleValue = sin(angle) * amplitude * envelope
            let pcmSample = Int16(max(-1.0, min(1.0, sampleValue)) * Double(Int16.max))
            data.appendLittleEndian(pcmSample)
        }

        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}

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

    init() {
        timer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshCountdown()
            }
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

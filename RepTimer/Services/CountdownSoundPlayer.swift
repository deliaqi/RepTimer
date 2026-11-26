import AVFoundation
import Foundation

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

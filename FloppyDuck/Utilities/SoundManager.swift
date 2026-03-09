import AVFoundation

/// Available game sound effects — all synthesized from waveforms, no audio assets needed.
enum GameSound: String {
    case flap
    case score
    case death
    case button
    case win
    case lose
    case medal
    case countTick
    case newBest
    case milestone
}

/// Generates and plays retro 8-bit style game sounds programmatically.
/// All audio is synthesized from sine/square waveforms — zero bundled assets.
/// Audio playback is dispatched to a dedicated serial queue to avoid blocking the render thread.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [GameSound: AVAudioPlayer] = [:]
    private var soundData: [GameSound: Data] = [:]
    private var bgmPlayer: AVAudioPlayer?

    /// Dedicated serial queue for audio playback — keeps AVAudioPlayer off the main/render thread.
    private let audioQueue = DispatchQueue(label: "com.floppyduck.audio", qos: .userInteractive)

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    private init() {
        setupSession()
        buildSounds()
    }

    /// Warm up the audio engine (call at app launch).
    func prepare() {
        // Singleton init already built all sounds.
        // Calling this from AppDelegate ensures sounds are ready before first play.
        // Pre-warm all players on the audio queue so first play has zero latency.
        audioQueue.async { [weak self] in
            self?.players.values.forEach { $0.prepareToPlay() }
            self?.bgmPlayer?.prepareToPlay()
        }
    }

    func play(_ sound: GameSound) {
        guard isEnabled else { return }
        audioQueue.async { [weak self] in
            guard let player = self?.players[sound] else { return }
            player.stop()
            player.currentTime = 0
            player.play()
        }
    }

    func startMenuMusic() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            guard self.isEnabled else { return }
            guard let bgmPlayer else { return }
            bgmPlayer.numberOfLoops = -1
            bgmPlayer.volume = 0.12
            if !bgmPlayer.isPlaying {
                bgmPlayer.currentTime = 0
                bgmPlayer.play()
            }
        }
    }

    func stopMenuMusic() {
        audioQueue.async { [weak self] in
            self?.bgmPlayer?.stop()
        }
    }

    func refreshAudioPreference() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            if self.isEnabled {
                return
            }
            self.players.values.forEach { $0.stop() }
            self.bgmPlayer?.stop()
        }
    }

    // MARK: - Setup

    private func setupSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func buildSounds() {
        let defs: [(GameSound, Data, Float)] = [
            (.flap,      flapWav(),      0.25),
            (.score,     scoreWav(),     0.35),
            (.death,     deathWav(),     0.40),
            (.button,    buttonWav(),    0.20),
            (.win,       winWav(),       0.45),
            (.lose,      loseWav(),      0.35),
            (.medal,     medalWav(),     0.40),
            (.countTick, countTickWav(), 0.15),
            (.newBest,   newBestWav(),   0.50),
            (.milestone, milestoneWav(), 0.30),
        ]
        for (sound, data, vol) in defs {
            soundData[sound] = data
            if let p = try? AVAudioPlayer(data: data) {
                p.volume = vol
                p.prepareToPlay()
                players[sound] = p
            }
        }

        let bgmData = menuBgmWav()
        if let player = try? AVAudioPlayer(data: bgmData) {
            player.volume = 0.12
            player.numberOfLoops = -1
            player.prepareToPlay()
            bgmPlayer = player
        }
    }

    // MARK: - WAV Builder

    private let sr = 44100 // sample rate

    /// Packs Float samples into a valid 16-bit mono WAV Data blob.
    private func wav(_ samples: [Float]) -> Data {
        let n = samples.count
        let dataBytes = n * 2
        let fileSize = UInt32(36 + dataBytes)

        var d = Data(capacity: 44 + dataBytes)

        func u32(_ v: UInt32) { var le = v.littleEndian; d.append(Data(bytes: &le, count: 4)) }
        func u16(_ v: UInt16) { var le = v.littleEndian; d.append(Data(bytes: &le, count: 2)) }
        func i16(_ v: Int16)  { var le = v.littleEndian; d.append(Data(bytes: &le, count: 2)) }

        // RIFF header
        d.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        u32(fileSize)
        d.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"

        // fmt sub-chunk
        d.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        u32(16)                       // sub-chunk size
        u16(1)                        // PCM
        u16(1)                        // mono
        u32(UInt32(sr))               // sample rate
        u32(UInt32(sr * 2))           // byte rate
        u16(2)                        // block align
        u16(16)                       // bits per sample

        // data sub-chunk
        d.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        u32(UInt32(dataBytes))

        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            i16(Int16(clamped * 32767))
        }
        return d
    }

    // MARK: - Waveform Generators

    private func sine(freq: Float, dur: Float, decay: Float = 0) -> [Float] {
        let count = Int(Float(sr) * dur)
        return (0..<count).map { i in
            let t = Float(i) / Float(sr)
            let env = decay > 0 ? max(0, 1.0 - t / decay) : 1.0
            return sin(2.0 * .pi * freq * t) * env
        }
    }

    private func square(freq: Float, dur: Float, decay: Float = 0) -> [Float] {
        let count = Int(Float(sr) * dur)
        return (0..<count).map { i in
            let t = Float(i) / Float(sr)
            let env = decay > 0 ? max(0, 1.0 - t / decay) : 1.0
            let phase = fmod(freq * t, 1.0)
            return (phase < 0.5 ? 0.5 : -0.5) * env
        }
    }

    private func chirp(f0: Float, f1: Float, dur: Float) -> [Float] {
        let count = Int(Float(sr) * dur)
        return (0..<count).map { i in
            let t = Float(i) / Float(sr)
            let p = t / dur
            let freq = f0 + (f1 - f0) * p
            return sin(2.0 * .pi * freq * t) * (1.0 - p) * 0.6
        }
    }

    private func silence(_ dur: Float) -> [Float] {
        [Float](repeating: 0, count: Int(Float(sr) * dur))
    }

    // MARK: - Sound Definitions

    private func flapWav() -> Data {
        wav(chirp(f0: 350, f1: 950, dur: 0.055))
    }

    private func scoreWav() -> Data {
        wav(sine(freq: 880, dur: 0.07, decay: 0.07) +
            silence(0.02) +
            sine(freq: 1320, dur: 0.10, decay: 0.10))
    }

    private func deathWav() -> Data {
        wav(chirp(f0: 420, f1: 80, dur: 0.22))
    }

    private func buttonWav() -> Data {
        wav(square(freq: 800, dur: 0.025, decay: 0.025))
    }

    private func winWav() -> Data {
        let notes: [Float] = [523.25, 659.25, 783.99, 1046.50]
        var s: [Float] = []
        for n in notes { s += sine(freq: n, dur: 0.10, decay: 0.12) + silence(0.015) }
        s += sine(freq: 1046.50, dur: 0.25, decay: 0.35)
        return wav(s)
    }

    private func loseWav() -> Data {
        let notes: [Float] = [400, 350, 300, 200]
        var s: [Float] = []
        for n in notes { s += sine(freq: n, dur: 0.12, decay: 0.15) + silence(0.01) }
        return wav(s)
    }

    private func medalWav() -> Data {
        wav(sine(freq: 1200, dur: 0.04, decay: 0.04) +
            sine(freq: 1600, dur: 0.12, decay: 0.16))
    }

    private func countTickWav() -> Data {
        wav(square(freq: 1000, dur: 0.018, decay: 0.018))
    }

    private func newBestWav() -> Data {
        let notes: [Float] = [523.25, 659.25, 783.99, 1046.50, 1318.51]
        var s: [Float] = []
        for (i, n) in notes.enumerated() {
            let d: Float = i == notes.count - 1 ? 0.35 : 0.07
            let dec: Float = i == notes.count - 1 ? 0.45 : 0.09
            s += sine(freq: n, dur: d, decay: dec)
            if i < notes.count - 1 { s += silence(0.008) }
        }
        return wav(s)
    }

    private func milestoneWav() -> Data {
        wav(sine(freq: 660, dur: 0.05, decay: 0.06) +
            sine(freq: 990, dur: 0.08, decay: 0.10))
    }

    private func menuBgmWav() -> Data {
        let melody: [Float] = [392, 440, 523.25, 440, 349.23, 392, 440, 523.25]
        var s: [Float] = []
        for note in melody {
            s += square(freq: note, dur: 0.10, decay: 0.12).map { $0 * 0.32 }
            s += silence(0.03)
            s += sine(freq: note / 2, dur: 0.13, decay: 0.20).map { $0 * 0.22 }
            s += silence(0.02)
        }
        s += silence(0.08)
        return wav(s)
    }
}

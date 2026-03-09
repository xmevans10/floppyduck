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
    private var playBgmPlayer: AVAudioPlayer?

    /// Skin-specific sound variants (flap, death) keyed by skin + sound.
    private var skinPlayers: [String: AVAudioPlayer] = [:]

    /// Currently equipped skin — set before gameplay to activate skin sounds.
    var activeSkin: DuckSkin = .classic

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
            guard let self else { return }
            // For flap/death, prefer skin-specific variant if available
            if (sound == .flap || sound == .death), self.activeSkin != .classic {
                let key = "\(self.activeSkin.rawValue)_\(sound.rawValue)"
                if let skinPlayer = self.skinPlayers[key] {
                    skinPlayer.stop()
                    skinPlayer.currentTime = 0
                    skinPlayer.play()
                    return
                }
            }
            guard let player = self.players[sound] else { return }
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

    func startPlayMusic() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            guard self.isEnabled else { return }
            // Stop menu music before starting gameplay music
            self.bgmPlayer?.stop()
            guard let playBgmPlayer else { return }
            playBgmPlayer.numberOfLoops = -1
            playBgmPlayer.volume = 0.10
            if !playBgmPlayer.isPlaying {
                playBgmPlayer.currentTime = 0
                playBgmPlayer.play()
            }
        }
    }

    func stopPlayMusic() {
        audioQueue.async { [weak self] in
            self?.playBgmPlayer?.stop()
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
            self.playBgmPlayer?.stop()
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

        let playData = playBgmWav()
        if let player = try? AVAudioPlayer(data: playData) {
            player.volume = 0.10
            player.numberOfLoops = -1
            player.prepareToPlay()
            playBgmPlayer = player
        }

        buildSkinSounds()
    }

    /// Build flap + death variants per skin for distinct character feel.
    private func buildSkinSounds() {
        // (skin, sound, data, volume)
        let variants: [(DuckSkin, GameSound, Data, Float)] = [
            // Cowboy — lower pitch, twangy
            (.cowboy, .flap,  wav(chirp(f0: 220, f1: 600, dur: 0.065)), 0.25),
            (.cowboy, .death, wav(chirp(f0: 300, f1: 60, dur: 0.28)),   0.40),

            // Alien — high-pitched, ethereal sine
            (.alien, .flap,  wav(sine(freq: 1200, dur: 0.04, decay: 0.05)), 0.22),
            (.alien, .death, wav(chirp(f0: 800, f1: 200, dur: 0.3)),        0.38),

            // Dinosaur — very low, powerful
            (.dinosaur, .flap,  wav(square(freq: 160, dur: 0.07, decay: 0.08)), 0.30),
            (.dinosaur, .death, wav(chirp(f0: 200, f1: 40, dur: 0.35)),         0.45),

            // Wizard — magical shimmer, triangle wave
            (.wizard, .flap,  wav(triangle(freq: 880, dur: 0.06, decay: 0.07) +
                                  sine(freq: 1320, dur: 0.03, decay: 0.04)),     0.25),
            (.wizard, .death, wav(chirp(f0: 660, f1: 110, dur: 0.25)),           0.40),

            // Devil — gritty square, growly
            (.devil, .flap,  wav(square(freq: 280, dur: 0.05, decay: 0.06)), 0.28),
            (.devil, .death, wav(square(freq: 180, dur: 0.08, decay: 0.12) +
                                 chirp(f0: 180, f1: 50, dur: 0.20)),         0.42),
        ]

        for (skin, sound, data, vol) in variants {
            let key = "\(skin.rawValue)_\(sound.rawValue)"
            if let p = try? AVAudioPlayer(data: data) {
                p.volume = vol
                p.prepareToPlay()
                skinPlayers[key] = p
            }
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

    /// Triangle wave — softer chiptune timbre for bass/background parts.
    private func triangle(freq: Float, dur: Float, decay: Float = 0) -> [Float] {
        let count = Int(Float(sr) * dur)
        return (0..<count).map { i in
            let t = Float(i) / Float(sr)
            let env = decay > 0 ? max(0, 1.0 - t / decay) : 1.0
            let phase = fmod(freq * t, 1.0)
            let raw = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)
            return raw * 0.5 * env
        }
    }

    /// Catchy, upbeat 8-bit menu chiptune — bouncy and cheerful like classic NES title screens.
    private func menuBgmWav() -> Data {
        // A/B structure for variety. Key of C major, ~120 BPM feel.
        let bpm: Float = 130
        let beat = 60.0 / bpm           // duration of one beat
        let eighth = beat / 2
        let sixteenth = beat / 4

        // Melody (square wave — bright lead)
        let melodyA: [(Float, Float)] = [
            // Bar 1: C E G A — ascending cheerful
            (523.25, eighth), (659.25, eighth), (783.99, eighth), (880.00, eighth),
            // Bar 2: G . E C — descending answer
            (783.99, eighth), (783.99, sixteenth), (0, sixteenth), (659.25, eighth), (523.25, eighth),
            // Bar 3: D F A G — stepping up
            (587.33, eighth), (698.46, eighth), (880.00, eighth), (783.99, eighth),
            // Bar 4: E . C . — resolve
            (659.25, beat), (523.25, beat),
        ]

        let melodyB: [(Float, Float)] = [
            // Bar 5: A G E C — descending run
            (880.00, eighth), (783.99, eighth), (659.25, eighth), (523.25, eighth),
            // Bar 6: D . F G — stepwise
            (587.33, eighth), (587.33, sixteenth), (0, sixteenth), (698.46, eighth), (783.99, eighth),
            // Bar 7: high C B A G — cascading
            (1046.50, eighth), (987.77, eighth), (880.00, eighth), (783.99, eighth),
            // Bar 8: E . C . — resolve home
            (659.25, beat), (523.25, beat),
        ]

        // Bass line (triangle — warm, rounded)
        let bassA: [(Float, Float)] = [
            (130.81, beat), (164.81, beat), (196.00, beat), (220.00, beat),
            (196.00, beat), (174.61, beat), (164.81, beat), (130.81, beat),
        ]

        let bassB: [(Float, Float)] = [
            (220.00, beat), (196.00, beat), (164.81, beat), (130.81, beat),
            (146.83, beat), (174.61, beat), (164.81, beat), (130.81, beat),
        ]

        func renderMelody(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += square(freq: freq, dur: dur, decay: dur * 1.1).map { $0 * 0.28 }
                }
            }
            return s
        }

        func renderBass(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += triangle(freq: freq, dur: dur, decay: dur * 1.2).map { $0 * 0.22 }
                }
            }
            return s
        }

        // Mix melody + bass for each section, then combine A + B
        func mixLayers(_ layer1: [Float], _ layer2: [Float]) -> [Float] {
            let len = max(layer1.count, layer2.count)
            return (0..<len).map { i in
                let a = i < layer1.count ? layer1[i] : 0
                let b = i < layer2.count ? layer2[i] : 0
                return a + b
            }
        }

        let sectionA = mixLayers(renderMelody(melodyA), renderBass(bassA))
        let sectionB = mixLayers(renderMelody(melodyB), renderBass(bassB))

        // Full loop: A → B (repeats via AVAudioPlayer)
        var full = sectionA + sectionB
        full += silence(0.06)  // tiny gap before loop point

        return wav(full)
    }

    /// Energetic 8-bit gameplay music — driving rhythm that builds tension without being distracting.
    private func playBgmWav() -> Data {
        let bpm: Float = 150
        let beat = 60.0 / bpm
        let eighth = beat / 2
        let sixteenth = beat / 4

        // Minimal, rhythmic melody — mostly arpeggiated chords so it doesn't distract
        let melodyA: [(Float, Float)] = [
            // Fast arpeggio pattern — C minor feel for tension
            (523.25, sixteenth), (622.25, sixteenth), (783.99, sixteenth), (622.25, sixteenth),
            (523.25, sixteenth), (622.25, sixteenth), (783.99, sixteenth), (622.25, sixteenth),
            // Shift to Ab
            (830.61, sixteenth), (622.25, sixteenth), (523.25, sixteenth), (622.25, sixteenth),
            (830.61, sixteenth), (622.25, sixteenth), (523.25, sixteenth), (0, sixteenth),
            // Repeat with variation
            (523.25, sixteenth), (622.25, sixteenth), (783.99, sixteenth), (932.33, sixteenth),
            (783.99, sixteenth), (622.25, sixteenth), (523.25, sixteenth), (622.25, sixteenth),
            (783.99, sixteenth), (622.25, sixteenth), (523.25, sixteenth), (466.16, sixteenth),
            (523.25, eighth), (0, eighth),
        ]

        let melodyB: [(Float, Float)] = [
            // Rising tension
            (587.33, sixteenth), (698.46, sixteenth), (880.00, sixteenth), (698.46, sixteenth),
            (587.33, sixteenth), (698.46, sixteenth), (880.00, sixteenth), (698.46, sixteenth),
            (932.33, sixteenth), (698.46, sixteenth), (587.33, sixteenth), (698.46, sixteenth),
            (932.33, sixteenth), (698.46, sixteenth), (587.33, sixteenth), (0, sixteenth),
            // Resolve down
            (523.25, sixteenth), (622.25, sixteenth), (783.99, sixteenth), (622.25, sixteenth),
            (523.25, sixteenth), (622.25, sixteenth), (783.99, sixteenth), (622.25, sixteenth),
            (523.25, eighth), (0, sixteenth), (523.25, sixteenth),
            (0, eighth), (0, eighth),
        ]

        // Driving bass line
        let bassA: [(Float, Float)] = [
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (103.83, eighth), (0, sixteenth), (103.83, sixteenth),
            (103.83, eighth), (0, sixteenth), (103.83, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (116.54, eighth), (116.54, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, eighth),
        ]

        let bassB: [(Float, Float)] = [
            (146.83, eighth), (0, sixteenth), (146.83, sixteenth),
            (146.83, eighth), (0, sixteenth), (146.83, sixteenth),
            (116.54, eighth), (0, sixteenth), (116.54, sixteenth),
            (116.54, eighth), (0, sixteenth), (116.54, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, eighth),
            (0, beat),
        ]

        func renderMelody(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += square(freq: freq, dur: dur * 0.85, decay: dur * 0.9).map { $0 * 0.20 }
                    s += silence(dur * 0.15)
                }
            }
            return s
        }

        func renderBass(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += triangle(freq: freq, dur: dur * 0.9, decay: dur).map { $0 * 0.18 }
                    s += silence(dur * 0.1)
                }
            }
            return s
        }

        func mixLayers(_ layer1: [Float], _ layer2: [Float]) -> [Float] {
            let len = max(layer1.count, layer2.count)
            return (0..<len).map { i in
                let a = i < layer1.count ? layer1[i] : 0
                let b = i < layer2.count ? layer2[i] : 0
                return a + b
            }
        }

        let sectionA = mixLayers(renderMelody(melodyA), renderBass(bassA))
        let sectionB = mixLayers(renderMelody(melodyB), renderBass(bassB))

        var full = sectionA + sectionB
        full += silence(0.04)
        return wav(full)
    }
}

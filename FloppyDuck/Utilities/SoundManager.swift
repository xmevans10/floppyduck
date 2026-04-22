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
    case quack
    case coin
    case powerUp
    case debuff
}

import Foundation

/// Manages all game audio — synthesized 8-bit SFX plus bundled chiptune music.
/// SFX are generated from sine/square waveforms at runtime.
/// Music uses Juhani Junkala's CC0 chiptune packs (Action for gameplay, Adventure for menus).
/// Audio playback is dispatched to a dedicated serial queue to avoid blocking the render thread.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [GameSound: AVAudioPlayer] = [:]
    private var soundData: [GameSound: Data] = [:]
    private var bgmPlayer: AVAudioPlayer?
    private var playBgmPlayer: AVAudioPlayer?

    /// Loaded menu music tracks (Junkala Adventure pack — CC0)
    private var menuTracks: [AVAudioPlayer] = []
    /// Loaded gameplay music tracks (Junkala Action pack — CC0)
    private var playTracks: [AVAudioPlayer] = []

    /// Per-theme synthesized gameplay music (keyed by theme rawValue).
    private var themePlayTracks: [String: AVAudioPlayer] = [:]
    /// Per-theme synthesized menu music (keyed by theme rawValue).
    private var themeMenuTracks: [String: AVAudioPlayer] = [:]
    /// Currently active background theme for music selection.
    private var activeTheme: BackgroundTheme = .day

    /// Per-skin sound variant players (keyed by "\(skin.rawValue)_\(sound.rawValue)")
    private var skinPlayers: [String: AVAudioPlayer] = [:]

    /// Currently active skin for sound variants
    private var activeSkin: DuckSkin = .classic

    /// Dedicated serial queue for audio playback — keeps AVAudioPlayer off the main/render thread.
    private let audioQueue = DispatchQueue(label: "com.floppyduck.audio", qos: .userInteractive)
    private var didPrepareAudio = false
    private var didSetupSession = false

    /// Cached preference — avoids UserDefaults dictionary lookup on every play() call.
    private var _isEnabled: Bool = true

    private var isEnabled: Bool { _isEnabled }

    private init() {
        // Cache the preference at init time (avoids UserDefaults lookup on every play() call)
        _isEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    /// Warm up the audio engine (call at app launch).
    func prepare() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.prepareIfNeeded()
        }
    }

    /// Set active background theme — determines which music track plays.
    func setActiveTheme(_ theme: BackgroundTheme) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.prepareIfNeeded()
            self.activeTheme = theme
            self.ensureThemeMusic(for: theme)
        }
    }

    /// Set active skin for per-skin sound variants (flap + death).
    func setActiveSkin(_ skin: DuckSkin) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.prepareIfNeeded()
            self.activeSkin = skin
            self.buildSkinVariants(for: skin)
        }
    }

    func play(_ sound: GameSound) {
        guard isEnabled else { return }
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.prepareIfNeeded()

            // Per-skin variant for flap and death
            if (sound == .flap || sound == .death) && self.activeSkin != .classic {
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
            self.prepareIfNeeded()
            guard self.isEnabled else { return }
            // Stop any currently playing menu music
            self.bgmPlayer?.stop()

            let theme = self.activeTheme

            // Try theme-specific bundled menu track first
            if let fileName = theme.menuMusicFile,
               let url = Bundle.main.url(forResource: fileName, withExtension: "m4a"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.numberOfLoops = -1
                player.volume = 0.18
                player.prepareToPlay()
                player.play()
                self.bgmPlayer = player
                return
            }

            // Try per-theme synthesized menu track
            self.ensureThemeMusic(for: theme)
            if let themeTrack = self.themeMenuTracks[theme.themeID] {
                themeTrack.numberOfLoops = -1
                themeTrack.volume = 0.14
                themeTrack.currentTime = 0
                themeTrack.play()
                self.bgmPlayer = themeTrack
                return
            }

            // Fallback: random from Adventure pack
            guard !self.menuTracks.isEmpty else { return }
            let track = self.menuTracks.randomElement()!
            track.numberOfLoops = -1
            track.volume = 0.18
            track.currentTime = 0
            track.play()
            self.bgmPlayer = track
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
            self.prepareIfNeeded()
            guard self.isEnabled else { return }
            // Stop menu BGM before starting gameplay BGM to prevent overlap
            self.bgmPlayer?.stop()
            // Stop any currently playing gameplay music
            self.playBgmPlayer?.stop()

            let theme = self.activeTheme

            // Try theme-specific bundled gameplay track first
            if let fileName = theme.gameplayMusicFile,
               let url = Bundle.main.url(forResource: fileName, withExtension: "m4a"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.numberOfLoops = -1
                player.volume = 0.15
                player.prepareToPlay()
                player.play()
                self.playBgmPlayer = player
                return
            }

            // Try per-theme synthesized gameplay track
            self.ensureThemeMusic(for: theme)
            if let themeTrack = self.themePlayTracks[theme.themeID] {
                themeTrack.numberOfLoops = -1
                themeTrack.volume = 0.12
                themeTrack.currentTime = 0
                themeTrack.play()
                self.playBgmPlayer = themeTrack
                return
            }

            // Fallback: random from Action pack
            guard !self.playTracks.isEmpty else { return }
            let track = self.playTracks.randomElement()!
            track.numberOfLoops = -1
            track.volume = 0.15
            track.currentTime = 0
            track.play()
            self.playBgmPlayer = track
        }
    }

    func stopPlayMusic() {
        audioQueue.async { [weak self] in
            self?.playBgmPlayer?.stop()
        }
    }

    func refreshAudioPreference() {
        // Sync cached preference from UserDefaults (main thread safe)
        _isEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        audioQueue.async { [weak self] in
            guard let self else { return }
            if self.isEnabled {
                self.prepareIfNeeded()
                // Sound was just re-enabled — restart whichever BGM track
                // is contextually appropriate. The caller's screen will also
                // trigger startMenuMusic/startPlayMusic on next transition,
                // but restarting here gives immediate feedback on toggle.
                if self.bgmPlayer != nil {
                    self.bgmPlayer?.currentTime = 0
                    self.bgmPlayer?.play()
                } else if self.playBgmPlayer != nil {
                    self.playBgmPlayer?.currentTime = 0
                    self.playBgmPlayer?.play()
                }
                return
            }
            self.players.values.forEach { $0.stop() }
            self.bgmPlayer?.stop()
            self.playBgmPlayer?.stop()
            self.menuTracks.forEach { $0.stop() }
            self.playTracks.forEach { $0.stop() }
            self.themePlayTracks.values.forEach { $0.stop() }
            self.themeMenuTracks.values.forEach { $0.stop() }
        }
    }

    // MARK: - Setup

    private func prepareIfNeeded() {
        guard !didPrepareAudio else { return }
        didPrepareAudio = true
        setupSession()
        buildSounds()
        players.values.forEach { $0.prepareToPlay() }
        menuTracks.forEach { $0.prepareToPlay() }
        playTracks.forEach { $0.prepareToPlay() }
    }

    private func setupSession() {
        guard !didSetupSession else { return }
        didSetupSession = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
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
            (.quack,     loadBundledQuack(),  0.60),
            (.coin,      coinWav(),      0.40),
            (.powerUp,   powerUpWav(),   0.35),
            (.debuff,    debuffWav(),    0.35),
        ]
        for (sound, data, vol) in defs {
            soundData[sound] = data
            if let p = try? AVAudioPlayer(data: data) {
                p.volume = vol
                p.prepareToPlay()
                players[sound] = p
            }
        }

        // Load menu music — Juhani Junkala "Chiptune Adventures" (CC0)
        let menuFiles = [
            "adventure_stage_select",
            "adventure_stage_1",
            "adventure_stage_2",
            "adventure_boss_fight",
        ]
        for name in menuFiles {
            if let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.18
                player.numberOfLoops = -1
                player.prepareToPlay()
                menuTracks.append(player)
            }
        }
        // Fallback: synthesized menu BGM if no files found
        if menuTracks.isEmpty {
            let bgmData = menuBgmWav()
            if let player = try? AVAudioPlayer(data: bgmData) {
                player.volume = 0.12
                player.numberOfLoops = -1
                player.prepareToPlay()
                menuTracks.append(player)
            }
        }
        bgmPlayer = menuTracks.first

        // Load gameplay music — Juhani Junkala "Retro Game Music Pack" (CC0)
        let playFiles = [
            "action_level_1",
            "action_level_2",
            "action_level_3",
        ]
        for name in playFiles {
            if let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.15
                player.numberOfLoops = -1
                player.prepareToPlay()
                playTracks.append(player)
            }
        }
        // Fallback: synthesized gameplay BGM if no files found
        if playTracks.isEmpty {
            let playData = playBgmWav()
            if let player = try? AVAudioPlayer(data: playData) {
                player.volume = 0.10
                player.numberOfLoops = -1
                player.prepareToPlay()
                playTracks.append(player)
            }
        }
        playBgmPlayer = playTracks.first
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

    /// Splash-screen quack — real duck quack loaded from bundled WAV asset.
    /// Source: Mixkit (royalty-free), trimmed to a single 0.26 s quack.
    private func loadBundledQuack() -> Data {
        if let url = Bundle.main.url(forResource: "quack", withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            print("[SoundManager] ✅ Loaded quack.wav from bundle (\(data.count) bytes)")
            return data
        }
        // Fallback: synthesized square-wave honk if the asset is missing
        print("[SoundManager] ⚠️ quack.wav not found in bundle — using synthesized fallback")
        return wav(square(freq: 600, dur: 0.12, decay: 0.15) +
                   silence(0.02) +
                   square(freq: 520, dur: 0.15, decay: 0.18))
    }

    /// Classic retro coin-collect sound — two quick ascending sine tones (B5 → E6).
    /// Think Mario coin: bright, satisfying, short.
    private func coinWav() -> Data {
        wav(sine(freq: 988, dur: 0.05, decay: 0.06) +
            sine(freq: 1319, dur: 0.12, decay: 0.15))
    }

    /// Ascending cheerful chime — positive power-up collect.
    /// Four quick rising sine tones (E5 → A5 → D6 → F6) with a sustained final note.
    private func powerUpWav() -> Data {
        let notes: [Float] = [659.25, 880.00, 1174.66, 1396.91]
        var s: [Float] = []
        for n in notes {
            s += sine(freq: n, dur: 0.06, decay: 0.08)
            s += silence(0.01)
        }
        s += sine(freq: 1396.91, dur: 0.12, decay: 0.18)
        return wav(s)
    }

    /// Descending warning tone — negative debuff collect.
    /// Four quick falling square-wave tones (A5 → E5 → B4 → G4) with a sustained low end.
    private func debuffWav() -> Data {
        let notes: [Float] = [880.00, 659.25, 493.88, 392.00]
        var s: [Float] = []
        for n in notes {
            s += square(freq: n, dur: 0.06, decay: 0.08)
            s += silence(0.01)
        }
        s += square(freq: 392.00, dur: 0.10, decay: 0.14)
        return wav(s)
    }

    // MARK: - Per-Skin Sound Variants (Item 11)

    /// Build per-skin flap and death sounds. Non-classic skins get pitch-shifted/modified waveforms.
    private func buildSkinVariants(for skin: DuckSkin) {
        guard skin != .classic else { return }
        let key_flap = "\(skin.rawValue)_flap"
        let key_death = "\(skin.rawValue)_death"

        // Skip if already built
        if skinPlayers[key_flap] != nil { return }

        let (flapData, flapVol) = self.skinFlapWav(skin: skin)
        let (deathData, deathVol) = self.skinDeathWav(skin: skin)

        if let p = try? AVAudioPlayer(data: flapData) {
            p.volume = flapVol
            p.prepareToPlay()
            self.skinPlayers[key_flap] = p
        }
        if let p = try? AVAudioPlayer(data: deathData) {
            p.volume = deathVol
            p.prepareToPlay()
            self.skinPlayers[key_death] = p
        }
    }

    /// Per-skin flap sound: pitch-shifted or different waveform.
    private func skinFlapWav(skin: DuckSkin) -> (Data, Float) {
        switch skin {
        case .cowboy:
            // Lower honk
            return (wav(chirp(f0: 220, f1: 500, dur: 0.07)), 0.28)
        case .alien:
            // High-pitched zap
            return (wav(sine(freq: 1800, dur: 0.04, decay: 0.04) + sine(freq: 2400, dur: 0.03, decay: 0.03)), 0.22)
        case .wizard:
            // Shimmer / sparkle
            return (wav(sine(freq: 1200, dur: 0.03, decay: 0.04) + sine(freq: 1600, dur: 0.03, decay: 0.04) + sine(freq: 2000, dur: 0.02, decay: 0.03)), 0.20)
        case .devil:
            // Low growl chirp
            return (wav(chirp(f0: 180, f1: 400, dur: 0.08)), 0.30)
        case .pirate:
            // Rough square wave flap
            return (wav(square(freq: 300, dur: 0.05, decay: 0.06)), 0.25)
        case .dinosaur:
            // Deep thud chirp
            return (wav(chirp(f0: 150, f1: 350, dur: 0.07)), 0.28)
        case .sailor:
            // Whistle-like
            return (wav(sine(freq: 900, dur: 0.04, decay: 0.05) + sine(freq: 1100, dur: 0.03, decay: 0.04)), 0.22)
        case .golden:
            // Bright bell
            return (wav(sine(freq: 1400, dur: 0.04, decay: 0.05) + sine(freq: 1800, dur: 0.04, decay: 0.05)), 0.25)
        case .classic:
            return (flapWav(), 0.25)
        }
    }

    /// Per-skin death sound: pitch-shifted or different waveform.
    private func skinDeathWav(skin: DuckSkin) -> (Data, Float) {
        switch skin {
        case .cowboy:
            // Lower longer honk descend
            return (wav(chirp(f0: 280, f1: 60, dur: 0.30)), 0.42)
        case .alien:
            // High zap descend
            return (wav(chirp(f0: 1200, f1: 200, dur: 0.25)), 0.38)
        case .wizard:
            // Descending shimmer
            return (wav(sine(freq: 800, dur: 0.08, decay: 0.10) + sine(freq: 500, dur: 0.08, decay: 0.10) + sine(freq: 300, dur: 0.12, decay: 0.14)), 0.38)
        case .devil:
            // Deep growl
            return (wav(chirp(f0: 300, f1: 50, dur: 0.35)), 0.45)
        case .pirate:
            // Square wave crash
            return (wav(square(freq: 350, dur: 0.10, decay: 0.12) + square(freq: 200, dur: 0.15, decay: 0.18)), 0.40)
        case .dinosaur:
            // Deep rumble
            return (wav(chirp(f0: 250, f1: 40, dur: 0.30)), 0.42)
        case .sailor:
            // Descending whistle
            return (wav(chirp(f0: 800, f1: 150, dur: 0.28)), 0.38)
        case .golden:
            // Bright crash descend
            return (wav(chirp(f0: 1000, f1: 120, dur: 0.28)), 0.42)
        case .classic:
            return (deathWav(), 0.40)
        }
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

    // MARK: - Per-Theme Synthesized Music

    /// Lazily generates and caches synthesized music for the given theme.
    /// Called on the audio queue — never blocks the main thread.
    private func ensureThemeMusic(for theme: BackgroundTheme) {
        let id = theme.themeID
        // Skip themes that use bundled files
        if theme.gameplayMusicFile != nil && theme.menuMusicFile != nil { return }
        guard themePlayTracks[id] == nil else { return }

        let (playData, menuData) = synthesizeThemeMusic(for: theme)

        if let p = try? AVAudioPlayer(data: playData) {
            p.volume = 0.12
            p.numberOfLoops = -1
            p.prepareToPlay()
            themePlayTracks[id] = p
        }
        if let m = try? AVAudioPlayer(data: menuData) {
            m.volume = 0.14
            m.numberOfLoops = -1
            m.prepareToPlay()
            themeMenuTracks[id] = m
        }
    }

    /// Returns (gameplayWav, menuWav) tailored to the theme's mood.
    private func synthesizeThemeMusic(for theme: BackgroundTheme) -> (Data, Data) {
        switch theme {
        case .western:     return (westernPlayWav(),    westernMenuWav())
        case .jungle:      return (junglePlayWav(),     jungleMenuWav())
        case .egypt:       return (egyptPlayWav(),      egyptMenuWav())
        case .cave:        return (cavePlayWav(),       caveMenuWav())
        case .mountain:    return (mountainPlayWav(),   mountainMenuWav())
        case .neonCity:    return (neonCityPlayWav(),   neonCityMenuWav())
        case .underwater:  return (underwaterPlayWav(), underwaterMenuWav())
        case .volcano:     return (volcanoPlayWav(),    volcanoMenuWav())
        case .arctic:      return (arcticPlayWav(),     arcticMenuWav())
        case .space:       return (spacePlayWav(),      spaceMenuWav())
        case .pixelTokyo:  return (tokyoPlayWav(),      tokyoMenuWav())
        default:           return (playBgmWav(),        menuBgmWav())
        }
    }

    // ────────────────────────────────────────────────────
    // WESTERN — twangy, bouncy country feel (G major)
    // ────────────────────────────────────────────────────

    private func westernPlayWav() -> Data {
        let bpm: Float = 140
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (392.00, eighth), (440.00, eighth), (493.88, eighth), (587.33, eighth),
            (659.25, eighth), (587.33, eighth), (493.88, eighth), (440.00, eighth),
            (392.00, eighth), (493.88, eighth), (587.33, eighth), (659.25, eighth),
            (783.99, eighth), (659.25, eighth), (587.33, eighth), (493.88, eighth),
            (440.00, beat), (392.00, beat),
        ]

        let bass: [(Float, Float)] = [
            (98.00, beat), (110.00, beat), (123.47, beat), (146.83, beat),
            (164.81, beat), (146.83, beat), (123.47, beat), (110.00, beat),
            (98.00, beat), (98.00, beat),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.22, bassVol: 0.18))
    }

    private func westernMenuWav() -> Data {
        let bpm: Float = 110
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (392.00, beat), (440.00, beat), (493.88, beat), (587.33, beat),
            (493.88, beat), (440.00, beat), (392.00, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (98.00, beat * 2), (110.00, beat * 2), (123.47, beat * 2), (98.00, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.16))
    }

    // ────────────────────────────────────────────────────
    // JUNGLE — percussive tribal beat with pentatonic melody
    // ────────────────────────────────────────────────────

    private func junglePlayWav() -> Data {
        let bpm: Float = 135
        let beat = 60.0 / bpm
        let eighth = beat / 2
        let sixteenth = beat / 4

        let melody: [(Float, Float)] = [
            (523.25, sixteenth), (587.33, sixteenth), (659.25, sixteenth), (783.99, sixteenth),
            (880.00, eighth), (783.99, eighth),
            (659.25, sixteenth), (587.33, sixteenth), (523.25, sixteenth), (0, sixteenth),
            (523.25, eighth), (659.25, eighth),
            (783.99, eighth), (880.00, sixteenth), (783.99, sixteenth),
            (659.25, eighth), (523.25, beat),
        ]

        let bass: [(Float, Float)] = [
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (146.83, eighth), (0, sixteenth), (146.83, sixteenth),
            (164.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (130.81, eighth), (0, eighth),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.20))
    }

    private func jungleMenuWav() -> Data {
        let bpm: Float = 100
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (523.25, beat), (659.25, beat), (783.99, beat), (880.00, beat),
            (783.99, beat), (659.25, beat), (523.25, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (130.81, beat * 2), (164.81, beat * 2), (146.83, beat * 2), (130.81, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.16))
    }

    // ────────────────────────────────────────────────────
    // EGYPT — mysterious Phrygian mode with ornamental runs
    // ────────────────────────────────────────────────────

    private func egyptPlayWav() -> Data {
        let bpm: Float = 128
        let beat = 60.0 / bpm
        let eighth = beat / 2
        let sixteenth = beat / 4

        // E Phrygian / Arabic scale: E F G# A B C D
        let melody: [(Float, Float)] = [
            (329.63, eighth), (349.23, sixteenth), (415.30, sixteenth),
            (440.00, eighth), (493.88, eighth),
            (523.25, eighth), (493.88, sixteenth), (440.00, sixteenth),
            (415.30, eighth), (349.23, eighth),
            (329.63, eighth), (349.23, sixteenth), (415.30, sixteenth),
            (440.00, eighth), (523.25, eighth),
            (493.88, beat), (329.63, beat),
        ]

        let bass: [(Float, Float)] = [
            (82.41, eighth), (0, sixteenth), (82.41, sixteenth),
            (87.31, eighth), (0, sixteenth), (82.41, sixteenth),
            (82.41, eighth), (0, sixteenth), (82.41, sixteenth),
            (87.31, eighth), (0, sixteenth), (82.41, sixteenth),
            (82.41, beat), (82.41, beat),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.22, bassVol: 0.18))
    }

    private func egyptMenuWav() -> Data {
        let bpm: Float = 95
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (329.63, beat), (349.23, beat), (415.30, beat), (440.00, beat),
            (415.30, beat), (349.23, beat), (329.63, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (82.41, beat * 2), (87.31, beat * 2), (82.41, beat * 2), (82.41, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.16))
    }

    // ────────────────────────────────────────────────────
    // CAVE — dark, echoing, sparse with low tones
    // ────────────────────────────────────────────────────

    private func cavePlayWav() -> Data {
        let bpm: Float = 110
        let beat = 60.0 / bpm
        let eighth = beat / 2

        // Minor key, sparse — lots of space
        let melody: [(Float, Float)] = [
            (261.63, beat), (0, eighth), (293.66, eighth),
            (311.13, beat), (0, eighth), (261.63, eighth),
            (246.94, beat), (0, eighth), (233.08, eighth),
            (261.63, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (65.41, beat * 2), (0, beat),
            (61.74, beat * 2), (0, beat),
            (65.41, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.16, bassVol: 0.20))
    }

    private func caveMenuWav() -> Data {
        let bpm: Float = 80
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (261.63, beat * 2), (293.66, beat * 2),
            (311.13, beat * 2), (261.63, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (65.41, beat * 4), (61.74, beat * 4),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.14, bassVol: 0.18))
    }

    // ────────────────────────────────────────────────────
    // MOUNTAIN — airy, bright, ascending motifs (D major)
    // ────────────────────────────────────────────────────

    private func mountainPlayWav() -> Data {
        let bpm: Float = 130
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (587.33, eighth), (659.25, eighth), (739.99, eighth), (880.00, eighth),
            (987.77, eighth), (880.00, eighth), (739.99, eighth), (659.25, eighth),
            (587.33, eighth), (739.99, eighth), (880.00, eighth), (987.77, eighth),
            (1174.66, eighth), (987.77, eighth), (880.00, eighth), (739.99, eighth),
            (659.25, beat), (587.33, beat),
        ]

        let bass: [(Float, Float)] = [
            (146.83, beat), (164.81, beat), (185.00, beat), (220.00, beat),
            (246.94, beat), (220.00, beat), (185.00, beat), (164.81, beat),
            (146.83, beat), (146.83, beat),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.16))
    }

    private func mountainMenuWav() -> Data {
        let bpm: Float = 100
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (587.33, beat), (659.25, beat), (739.99, beat), (880.00, beat),
            (739.99, beat), (659.25, beat), (587.33, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (146.83, beat * 2), (164.81, beat * 2), (185.00, beat * 2), (146.83, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.14))
    }

    // ────────────────────────────────────────────────────
    // NEON CITY — driving synth-wave arpeggios (A minor)
    // ────────────────────────────────────────────────────

    private func neonCityPlayWav() -> Data {
        let bpm: Float = 145
        let beat = 60.0 / bpm
        let sixteenth = beat / 4

        let melody: [(Float, Float)] = [
            (440.00, sixteenth), (523.25, sixteenth), (659.25, sixteenth), (523.25, sixteenth),
            (440.00, sixteenth), (523.25, sixteenth), (659.25, sixteenth), (783.99, sixteenth),
            (880.00, sixteenth), (783.99, sixteenth), (659.25, sixteenth), (523.25, sixteenth),
            (440.00, sixteenth), (523.25, sixteenth), (659.25, sixteenth), (523.25, sixteenth),
            (392.00, sixteenth), (440.00, sixteenth), (523.25, sixteenth), (440.00, sixteenth),
            (392.00, sixteenth), (440.00, sixteenth), (523.25, sixteenth), (659.25, sixteenth),
            (523.25, beat), (0, beat / 2), (440.00, beat / 2),
        ]

        let bass: [(Float, Float)] = [
            (110.00, beat), (0, sixteenth), (110.00, sixteenth), (0, beat / 2),
            (130.81, beat), (0, sixteenth), (130.81, sixteenth), (0, beat / 2),
            (110.00, beat), (0, sixteenth), (110.00, sixteenth), (0, beat / 2),
            (98.00, beat), (0, beat / 2), (110.00, beat / 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.20))
    }

    private func neonCityMenuWav() -> Data {
        let bpm: Float = 115
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (440.00, eighth), (523.25, eighth), (659.25, eighth), (783.99, eighth),
            (659.25, eighth), (523.25, eighth), (440.00, beat), (0, beat),
        ]

        let bass: [(Float, Float)] = [
            (110.00, beat * 2), (130.81, beat * 2), (98.00, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.16, bassVol: 0.18))
    }

    // ────────────────────────────────────────────────────
    // UNDERWATER — dreamy, flowing, lots of sustained notes
    // ────────────────────────────────────────────────────

    private func underwaterPlayWav() -> Data {
        let bpm: Float = 105
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (523.25, beat), (622.25, eighth), (698.46, eighth),
            (783.99, beat), (698.46, eighth), (622.25, eighth),
            (523.25, beat), (466.16, eighth), (523.25, eighth),
            (622.25, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (130.81, beat * 2), (155.56, beat * 2),
            (130.81, beat * 2), (116.54, beat * 2),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.16))
    }

    private func underwaterMenuWav() -> Data {
        let bpm: Float = 80
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (523.25, beat * 2), (622.25, beat * 2),
            (698.46, beat * 2), (523.25, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (130.81, beat * 4), (116.54, beat * 4),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.16, bassVol: 0.14))
    }

    // ────────────────────────────────────────────────────
    // VOLCANO — aggressive, driving minor key (E minor)
    // ────────────────────────────────────────────────────

    private func volcanoPlayWav() -> Data {
        let bpm: Float = 155
        let beat = 60.0 / bpm
        let eighth = beat / 2
        let sixteenth = beat / 4

        let melody: [(Float, Float)] = [
            (329.63, sixteenth), (392.00, sixteenth), (440.00, sixteenth), (493.88, sixteenth),
            (523.25, eighth), (493.88, eighth),
            (440.00, sixteenth), (392.00, sixteenth), (329.63, sixteenth), (392.00, sixteenth),
            (440.00, eighth), (523.25, eighth),
            (659.25, eighth), (587.33, sixteenth), (523.25, sixteenth),
            (493.88, eighth), (440.00, eighth),
            (329.63, beat), (0, beat / 2), (329.63, beat / 2),
        ]

        let bass: [(Float, Float)] = [
            (82.41, eighth), (0, sixteenth), (82.41, sixteenth),
            (82.41, eighth), (0, sixteenth), (82.41, sixteenth),
            (98.00, eighth), (0, sixteenth), (98.00, sixteenth),
            (82.41, eighth), (0, sixteenth), (82.41, sixteenth),
            (82.41, beat), (0, beat / 2), (82.41, beat / 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.22, bassVol: 0.22))
    }

    private func volcanoMenuWav() -> Data {
        let bpm: Float = 120
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (329.63, beat), (392.00, beat), (440.00, beat), (493.88, beat),
            (440.00, beat), (392.00, beat), (329.63, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (82.41, beat * 2), (98.00, beat * 2), (82.41, beat * 2), (82.41, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.18))
    }

    // ────────────────────────────────────────────────────
    // ARCTIC — crystalline, high-register, gentle (F major)
    // ────────────────────────────────────────────────────

    private func arcticPlayWav() -> Data {
        let bpm: Float = 120
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (698.46, eighth), (783.99, eighth), (880.00, eighth), (1046.50, eighth),
            (880.00, eighth), (783.99, eighth), (698.46, eighth), (659.25, eighth),
            (698.46, eighth), (880.00, eighth), (1046.50, eighth), (1174.66, eighth),
            (1046.50, beat), (880.00, beat),
        ]

        let bass: [(Float, Float)] = [
            (174.61, beat), (196.00, beat), (220.00, beat), (261.63, beat),
            (174.61, beat), (220.00, beat), (261.63, beat), (220.00, beat),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.14))
    }

    private func arcticMenuWav() -> Data {
        let bpm: Float = 90
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (698.46, beat), (880.00, beat), (1046.50, beat), (880.00, beat),
            (698.46, beat * 2), (0, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (174.61, beat * 4), (220.00, beat * 4),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.16, bassVol: 0.12))
    }

    // ────────────────────────────────────────────────────
    // SPACE — ambient, slow, ethereal (whole-tone feel)
    // ────────────────────────────────────────────────────

    private func spacePlayWav() -> Data {
        let bpm: Float = 95
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (523.25, beat), (587.33, eighth), (659.25, eighth),
            (739.99, beat), (0, eighth), (659.25, eighth),
            (587.33, beat), (523.25, eighth), (466.16, eighth),
            (523.25, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (130.81, beat * 2), (146.83, beat * 2),
            (130.81, beat * 2), (116.54, beat * 2),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.14, bassVol: 0.16))
    }

    private func spaceMenuWav() -> Data {
        let bpm: Float = 70
        let beat = 60.0 / bpm

        let melody: [(Float, Float)] = [
            (523.25, beat * 2), (587.33, beat * 2),
            (659.25, beat * 2), (523.25, beat * 2),
        ]

        let bass: [(Float, Float)] = [
            (130.81, beat * 4), (116.54, beat * 4),
        ]

        return wav(mixThemeLayersSine(melody: melody, bass: bass, melVol: 0.12, bassVol: 0.14))
    }

    // ────────────────────────────────────────────────────
    // PIXEL TOKYO — fast, poppy chiptune (Bb major)
    // ────────────────────────────────────────────────────

    private func tokyoPlayWav() -> Data {
        let bpm: Float = 160
        let beat = 60.0 / bpm
        let eighth = beat / 2
        let sixteenth = beat / 4

        let melody: [(Float, Float)] = [
            (466.16, sixteenth), (523.25, sixteenth), (587.33, sixteenth), (698.46, sixteenth),
            (783.99, eighth), (698.46, eighth),
            (587.33, sixteenth), (523.25, sixteenth), (466.16, sixteenth), (523.25, sixteenth),
            (587.33, eighth), (698.46, eighth),
            (783.99, sixteenth), (932.33, sixteenth), (783.99, sixteenth), (698.46, sixteenth),
            (587.33, eighth), (466.16, eighth),
            (523.25, beat), (0, beat / 2), (466.16, beat / 2),
        ]

        let bass: [(Float, Float)] = [
            (116.54, eighth), (0, sixteenth), (116.54, sixteenth),
            (130.81, eighth), (0, sixteenth), (130.81, sixteenth),
            (116.54, eighth), (0, sixteenth), (116.54, sixteenth),
            (110.00, eighth), (0, sixteenth), (116.54, sixteenth),
            (116.54, beat), (0, beat / 2), (116.54, beat / 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.20, bassVol: 0.18))
    }

    private func tokyoMenuWav() -> Data {
        let bpm: Float = 125
        let beat = 60.0 / bpm
        let eighth = beat / 2

        let melody: [(Float, Float)] = [
            (466.16, eighth), (523.25, eighth), (587.33, eighth), (698.46, eighth),
            (587.33, eighth), (523.25, eighth), (466.16, beat), (0, beat),
        ]

        let bass: [(Float, Float)] = [
            (116.54, beat * 2), (130.81, beat * 2), (110.00, beat * 2),
        ]

        return wav(mixThemeLayers(melody: melody, bass: bass, melVol: 0.18, bassVol: 0.16))
    }

    // MARK: - Theme Music Mixing Helpers

    /// Mix square-wave melody + triangle bass into one sample array (standard chiptune).
    private func mixThemeLayers(melody: [(Float, Float)], bass: [(Float, Float)],
                                melVol: Float, bassVol: Float) -> [Float] {
        func renderMelody(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += square(freq: freq, dur: dur * 0.85, decay: dur * 0.9).map { $0 * melVol }
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
                    s += triangle(freq: freq, dur: dur * 0.9, decay: dur).map { $0 * bassVol }
                    s += silence(dur * 0.1)
                }
            }
            return s
        }

        let melSamples = renderMelody(melody)
        let bassSamples = renderBass(bass)
        let len = max(melSamples.count, bassSamples.count)
        var result = (0..<len).map { i in
            let a = i < melSamples.count ? melSamples[i] : 0
            let b = i < bassSamples.count ? bassSamples[i] : 0
            return a + b
        }
        result += silence(0.04)
        return result
    }

    /// Mix sine-wave melody + triangle bass (softer, dreamier themes like underwater/space).
    private func mixThemeLayersSine(melody: [(Float, Float)], bass: [(Float, Float)],
                                    melVol: Float, bassVol: Float) -> [Float] {
        func renderMelody(_ notes: [(Float, Float)]) -> [Float] {
            var s: [Float] = []
            for (freq, dur) in notes {
                if freq == 0 {
                    s += silence(dur)
                } else {
                    s += sine(freq: freq, dur: dur * 0.9, decay: dur * 1.1).map { $0 * melVol }
                    s += silence(dur * 0.1)
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
                    s += triangle(freq: freq, dur: dur * 0.9, decay: dur).map { $0 * bassVol }
                    s += silence(dur * 0.1)
                }
            }
            return s
        }

        let melSamples = renderMelody(melody)
        let bassSamples = renderBass(bass)
        let len = max(melSamples.count, bassSamples.count)
        var result = (0..<len).map { i in
            let a = i < melSamples.count ? melSamples[i] : 0
            let b = i < bassSamples.count ? bassSamples[i] : 0
            return a + b
        }
        result += silence(0.04)
        return result
    }
}

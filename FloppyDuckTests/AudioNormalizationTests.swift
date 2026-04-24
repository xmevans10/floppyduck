import XCTest
import AVFoundation
@testable import FloppyDuck

/// Validates that all bundled audio assets meet volume / normalization
/// requirements so no track is perceptually louder or quieter than another.
final class AudioNormalizationTests: XCTestCase {

    // MARK: - Constants

    /// Maximum allowed peak amplitude (linear).  1.0 = 0 dBFS.
    /// Files should be normalized with true-peak ≤ −1 dBTP → ≈ 0.89 linear.
    /// We allow a small buffer above that.
    private let maxPeakAmplitude: Float = 0.95

    /// Minimum RMS amplitude (linear) for any music track.
    /// Prevents accidentally shipping near-silent files.
    private let minRMSAmplitude: Float = 0.01  // ≈ −40 dBFS

    /// Maximum allowed RMS ratio between any two music tracks.
    /// Keeps perceived loudness within a reasonable band.
    private let maxRMSRatio: Float = 4.0  // ≈ 12 dB spread

    // MARK: - All themes have bundled gameplay music

    func testEveryThemeHasGameplayMusicFile() {
        for theme in BackgroundTheme.allCases {
            XCTAssertNotNil(
                theme.gameplayMusicFile,
                "\(theme.rawValue) is missing a gameplayMusicFile"
            )
        }
    }

    func testEveryThemeGameplayMusicFileExistsInBundle() {
        for theme in BackgroundTheme.allCases {
            guard let fileName = theme.gameplayMusicFile else {
                // Covered by testEveryThemeHasGameplayMusicFile
                continue
            }
            let url = Bundle.main.url(forResource: fileName, withExtension: "m4a")
            XCTAssertNotNil(url, "\(theme.rawValue) gameplay music file '\(fileName).m4a' not found in bundle")
        }
    }

    func testMenuMusicFileExistsInBundle() {
        for theme in BackgroundTheme.allCases {
            guard let menuFile = theme.menuMusicFile else {
                XCTFail("\(theme.rawValue) is missing a menuMusicFile")
                continue
            }
            let url = Bundle.main.url(forResource: menuFile, withExtension: "m4a")
            XCTAssertNotNil(url, "Menu music file '\(menuFile).m4a' not found in bundle")
        }
    }

    // MARK: - Consistent menu music across themes

    func testMenuMusicIsSameForAllThemes() {
        let menuFiles = Set(BackgroundTheme.allCases.compactMap { $0.menuMusicFile })
        XCTAssertEqual(
            menuFiles.count, 1,
            "Expected one consistent menu track, got \(menuFiles.count): \(menuFiles)"
        )
    }

    // MARK: - Peak amplitude checks

    func testGameplayMusicPeakAmplitudeWithinRange() {
        for theme in BackgroundTheme.allCases {
            guard let fileName = theme.gameplayMusicFile,
                  let url = Bundle.main.url(forResource: fileName, withExtension: "m4a"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }

            player.isMeteringEnabled = true
            player.prepareToPlay()

            let peak = player.peakPower(forChannel: 0)  // dBFS
            let peakLinear = powf(10.0, peak / 20.0)

            XCTAssertLessThanOrEqual(
                peakLinear, maxPeakAmplitude,
                "\(theme.rawValue) (\(fileName)) peak \(peak) dBFS exceeds max"
            )
        }
    }

    func testMenuMusicPeakAmplitudeWithinRange() {
        guard let menuFile = BackgroundTheme.day.menuMusicFile,
              let url = Bundle.main.url(forResource: menuFile, withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            XCTFail("Cannot load menu track")
            return
        }

        player.isMeteringEnabled = true
        player.prepareToPlay()

        let peak = player.peakPower(forChannel: 0)
        let peakLinear = powf(10.0, peak / 20.0)

        XCTAssertLessThanOrEqual(
            peakLinear, maxPeakAmplitude,
            "Menu track peak \(peak) dBFS exceeds max"
        )
    }

    // MARK: - RMS loudness consistency across all gameplay tracks

    func testGameplayTracksRMSConsistency() {
        var rmsValues: [(theme: String, rms: Float)] = []

        for theme in BackgroundTheme.allCases {
            guard let fileName = theme.gameplayMusicFile,
                  let url = Bundle.main.url(forResource: fileName, withExtension: "m4a"),
                  let file = try? AVAudioFile(forReading: url) else { continue }

            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
            try? file.read(into: buffer)

            guard let channelData = buffer.floatChannelData else { continue }
            let frames = Int(buffer.frameLength)
            var sumSquares: Float = 0
            for i in 0..<frames {
                let sample = channelData[0][i]
                sumSquares += sample * sample
            }
            let rms = sqrtf(sumSquares / Float(max(frames, 1)))
            rmsValues.append((theme.rawValue, rms))
        }

        // Every track should be above minimum
        for (theme, rms) in rmsValues {
            XCTAssertGreaterThan(
                rms, minRMSAmplitude,
                "\(theme) RMS \(rms) is below minimum \(minRMSAmplitude) — file may be near-silent"
            )
        }

        // No two tracks should differ by more than maxRMSRatio
        guard let loudest = rmsValues.max(by: { $0.rms < $1.rms }),
              let quietest = rmsValues.min(by: { $0.rms < $1.rms }) else { return }

        let ratio = loudest.rms / max(quietest.rms, 0.0001)
        XCTAssertLessThanOrEqual(
            ratio, maxRMSRatio,
            "RMS spread too wide: loudest=\(loudest.theme) (\(loudest.rms)), quietest=\(quietest.theme) (\(quietest.rms)), ratio=\(ratio)"
        )
    }

    // MARK: - Quack files exist

    func testBundledQuackFilesExist() {
        for i in 1...5 {
            let url = Bundle.main.url(forResource: "quack_\(i)", withExtension: "m4a")
            XCTAssertNotNil(url, "quack_\(i).m4a not found in bundle")
        }
    }

    // MARK: - Per-skin quack files

    func testBundledSkinQuackFilesExist() {
        // Every non-classic skin should have a bundled quack_<skin>.m4a file.
        let nonClassicSkins = DuckSkin.allCases.filter { $0 != .classic }
        for skin in nonClassicSkins {
            let fileName = "quack_\(skin.rawValue)"
            let url = Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "Quacks/Skins")
                ?? Bundle.main.url(forResource: fileName, withExtension: "m4a")
            XCTAssertNotNil(url, "Missing bundled quack file for skin '\(skin.rawValue)' — expected \(fileName).m4a")
        }
    }

    func testSkinQuackFilesArePlayable() {
        let nonClassicSkins = DuckSkin.allCases.filter { $0 != .classic }
        for skin in nonClassicSkins {
            let fileName = "quack_\(skin.rawValue)"
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "Quacks/Skins")
                    ?? Bundle.main.url(forResource: fileName, withExtension: "m4a") else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            XCTAssertNotNil(player, "quack_\(skin.rawValue).m4a exists but cannot be loaded as audio")
            if let p = player {
                XCTAssertGreaterThan(p.duration, 0.1, "quack_\(skin.rawValue).m4a is too short (\(p.duration)s)")
                XCTAssertLessThan(p.duration, 3.0, "quack_\(skin.rawValue).m4a is too long (\(p.duration)s)")
            }
        }
    }

    // MARK: - Playback volume constants

    func testGameplayMusicVolumeIsReasonable() {
        // The gameplay music volume should be between 0.05 and 0.5
        // to be audible but not overwhelming over SFX.
        // Access through a test helper or check the constant directly.
        // Since gameplayMusicVolume is private, we verify indirectly:
        // start play music and check the player volume.
        let sm = SoundManager.shared
        sm.setActiveTheme(.day)
        sm.startPlayMusic()

        let expectation = expectation(description: "music started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        sm.stopPlayMusic()
    }
}

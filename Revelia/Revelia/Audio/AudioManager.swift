// Revelia/Audio/AudioManager.swift

@preconcurrency import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    enum SoundEffect {
        case menuClick
        case safeScan
        case cascade
        case hazardClick
        case destructionImpact
        case destructionCrackWave
        case tag
        case win
        case beaconTarget
        case beaconClear
        case conductorTarget
        case conductorPulse
        case sonarToggle
        case pauseOpen
        case pauseClose

        var fileName: String {
            switch self {
            case .menuClick:            return AudioAssets.SFX.menuClick
            case .safeScan:             return AudioAssets.SFX.safeScan
            case .cascade:              return AudioAssets.SFX.cascade
            case .hazardClick:          return AudioAssets.SFX.hazardLoss
            case .destructionImpact:    return AudioAssets.SFX.hazardLoss
            case .destructionCrackWave: return AudioAssets.SFX.hazardLoss
            case .tag:                  return AudioAssets.SFX.tagPlace
            case .win:                  return AudioAssets.SFX.win
            case .beaconTarget:         return AudioAssets.SFX.beaconTarget
            case .beaconClear:          return AudioAssets.SFX.beaconClear
            case .conductorTarget:      return AudioAssets.SFX.conductorTarget
            case .conductorPulse:       return AudioAssets.SFX.conductorPulse
            case .sonarToggle:          return AudioAssets.SFX.sonarToggle
            case .pauseOpen:            return AudioAssets.SFX.pauseOpen
            case .pauseClose:           return AudioAssets.SFX.pauseClose
            }
        }

        var volume: Float {
            switch self {
            case .cascade:
                return 0.34
            case .destructionImpact, .destructionCrackWave:
                return 0.42
            case .win:
                return 0.40
            default:
                return 0.36
            }
        }

        var minimumInterval: TimeInterval {
            switch self {
            case .menuClick, .tag, .safeScan:
                return 0.05
            case .cascade:
                return 0.2
            case .destructionImpact, .destructionCrackWave:
                return 0.1
            case .sonarToggle:
                return 0.08
            default:
                return 0.0
            }
        }
    }

    private var backgroundMusicEnabled = true
    private var gameSoundsEnabled = true
    private var appIsActive = true
    private var desiredScreen: AudioScreen?

    private var currentMusicPlayer: AVAudioPlayer?
    private var currentMusicFileName: String?
    private var retiringMusicPlayers: [AVAudioPlayer] = []
    private var fadeTimers: [ObjectIdentifier: Timer] = [:]
    private var fadeStates: [ObjectIdentifier: FadeState] = [:]
    private var effectPlayers: [AVAudioPlayer] = []
    private var missingAssets: Set<String> = []
    private var lastEffectPlayTimes: [String: Date] = [:]

    private let musicTargetVolume: Float = 0.28

    private final class FadeState {
        let player: AVAudioPlayer
        let playerID: ObjectIdentifier
        let startVolume: Float
        let targetVolume: Float
        let stepCount: Int
        let stopWhenFinished: Bool
        var currentStep: Int = 0

        init(
            player: AVAudioPlayer,
            startVolume: Float,
            targetVolume: Float,
            stepCount: Int,
            stopWhenFinished: Bool
        ) {
            self.player = player
            self.playerID = ObjectIdentifier(player)
            self.startVolume = startVolume
            self.targetVolume = targetVolume
            self.stepCount = stepCount
            self.stopWhenFinished = stopWhenFinished
        }
    }

    func setBackgroundMusicEnabled(_ enabled: Bool) {
        backgroundMusicEnabled = enabled
        if enabled {
            syncDesiredMusic()
        } else {
            fadeOutCurrentMusic(duration: 0.3)
        }
    }

    func setGameSoundsEnabled(_ enabled: Bool) {
        gameSoundsEnabled = enabled
        if !enabled {
            stopAllEffects()
        }
    }

    func setScenePhase(_ phase: ScenePhase) {
        appIsActive = phase == .active
        if appIsActive {
            syncDesiredMusic()
        } else {
            fadeOutCurrentMusic(duration: 0.25)
            stopAllEffects()
        }
    }

    func transition(to screen: AudioScreen) {
        desiredScreen = screen
        syncDesiredMusic()
    }

    func fadeOutMusic(duration: TimeInterval) {
        fadeOutCurrentMusic(duration: duration)
    }

    func play(_ effect: SoundEffect) {
        guard appIsActive, gameSoundsEnabled else { return }

        let now = Date()
        if let lastPlayed = lastEffectPlayTimes[effect.fileName],
           now.timeIntervalSince(lastPlayed) < effect.minimumInterval {
            return
        }
        lastEffectPlayTimes[effect.fileName] = now

        guard let player = makePlayer(for: effect.fileName) else { return }
        player.delegate = self
        player.volume = effect.volume
        player.numberOfLoops = 0
        player.prepareToPlay()
        effectPlayers.append(player)
        player.play()
    }

    func playMenuClick() {
        play(.menuClick)
    }

    func stopAllEffects() {
        for player in effectPlayers {
            player.stop()
        }
        effectPlayers.removeAll()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        effectPlayers.removeAll { $0 === player }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        effectPlayers.removeAll { $0 === player }
    }

    private func syncDesiredMusic() {
        guard backgroundMusicEnabled, appIsActive, let desiredScreen else { return }
        let fileName = desiredScreen.musicFileName
        guard currentMusicFileName != fileName else {
            fade(player: currentMusicPlayer, to: musicTargetVolume, duration: 0.2, stopWhenFinished: false)
            return
        }

        guard let nextPlayer = makePlayer(for: fileName) else {
            fadeOutCurrentMusic(duration: 0.25)
            return
        }

        let previousPlayer = currentMusicPlayer

        currentMusicPlayer = nextPlayer
        currentMusicFileName = fileName
        nextPlayer.numberOfLoops = -1
        nextPlayer.volume = 0
        nextPlayer.prepareToPlay()
        nextPlayer.play()
        fade(player: nextPlayer, to: musicTargetVolume, duration: 0.45, stopWhenFinished: false)

        if let previousPlayer {
            retiringMusicPlayers.append(previousPlayer)
            fade(player: previousPlayer, to: 0, duration: 0.45, stopWhenFinished: true)
        }
    }

    private func fadeOutCurrentMusic(duration: TimeInterval) {
        guard let currentMusicPlayer else {
            currentMusicFileName = nil
            return
        }
        retiringMusicPlayers.append(currentMusicPlayer)
        fade(player: currentMusicPlayer, to: 0, duration: duration, stopWhenFinished: true)
        self.currentMusicPlayer = nil
        self.currentMusicFileName = nil
    }

    private func fade(player: AVAudioPlayer?,
                      to targetVolume: Float,
                      duration: TimeInterval,
                      stopWhenFinished: Bool) {
        guard let player else { return }

        let identifier = ObjectIdentifier(player)
        fadeTimers[identifier]?.invalidate()
        fadeStates.removeValue(forKey: identifier)

        let stepCount = max(1, Int(duration / 0.05))
        let stepDuration = duration / Double(stepCount)
        let state = FadeState(
            player: player,
            startVolume: player.volume,
            targetVolume: targetVolume,
            stepCount: stepCount,
            stopWhenFinished: stopWhenFinished
        )

        fadeStates[identifier] = state
        let timer = Timer(timeInterval: stepDuration, target: self, selector: #selector(handleFadeTimer(_:)), userInfo: identifier, repeats: true)

        RunLoop.main.add(timer, forMode: .common)
        fadeTimers[identifier] = timer
    }

    @objc private func handleFadeTimer(_ timer: Timer) {
        guard
            let identifier = timer.userInfo as? ObjectIdentifier,
            let state = fadeStates[identifier]
        else {
            timer.invalidate()
            return
        }

        state.currentStep += 1
        let progress = min(1.0, Float(state.currentStep) / Float(state.stepCount))
        state.player.volume = state.startVolume + (state.targetVolume - state.startVolume) * progress

        if progress >= 1.0 {
            timer.invalidate()
            fadeTimers.removeValue(forKey: identifier)
            fadeStates.removeValue(forKey: identifier)
            if state.stopWhenFinished {
                state.player.stop()
                retiringMusicPlayers.removeAll { $0 === state.player }
            }
        }
    }

    private func makePlayer(for fileName: String) -> AVAudioPlayer? {
        guard let url = bundleURL(for: fileName) else {
            reportMissingAsset(fileName)
            return nil
        }

        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            print("[AudioManager] Failed to load audio asset \(fileName): \(error)")
            return nil
        }
    }

    private func bundleURL(for fileName: String) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    private func reportMissingAsset(_ fileName: String) {
        guard missingAssets.insert(fileName).inserted else { return }
        print("[AudioManager] Missing audio asset: \(fileName)")
    }
}

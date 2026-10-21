import Foundation
import MediaPlayer

/// Protocol for controlling active web media playback from remote CarPlay / steering wheel commands
public protocol MediaPlaybackControllable: AnyObject {
    func playMedia()
    func pauseMedia()
    func togglePlayPauseMedia()
    func seekForward(seconds: Double)
    func seekBackward(seconds: Double)
    func seekTo(seconds: Double)
}

/// Manages system Now Playing lock-screen and CarPlay dashboard metadata and steering wheel controls
public final class NowPlayingManager {
    public static let shared = NowPlayingManager()

    public weak var playbackController: MediaPlaybackControllable?

    private init() {
        setupRemoteCommands()
    }

    /// Sets up steering wheel and CarPlay head unit remote command listeners
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 1. Play / Pause / Toggle
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playbackController?.playMedia()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playbackController?.pauseMedia()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.playbackController?.togglePlayPauseMedia()
            return .success
        }

        // 2. Skip Forward / Backward (Discrete step, default 5s)
        let initialSeconds = SettingsManager.shared.seekInterval.rawValue
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: initialSeconds)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            let step = Double(SettingsManager.shared.seekInterval.rawValue)
            self?.playbackController?.seekForward(seconds: step)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: initialSeconds)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            let step = Double(SettingsManager.shared.seekInterval.rawValue)
            self?.playbackController?.seekBackward(seconds: step)
            return .success
        }

        // 3. Continuous Seek Forward / Backward (Holding steering wheel buttons)
        commandCenter.seekForwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.addTarget { [weak self] event in
            if let seekEvent = event as? MPSeekCommandEvent, seekEvent.type == .beginSeeking {
                let step = Double(SettingsManager.shared.seekInterval.rawValue)
                self?.playbackController?.seekForward(seconds: step)
            }
            return .success
        }

        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.seekBackwardCommand.addTarget { [weak self] event in
            if let seekEvent = event as? MPSeekCommandEvent, seekEvent.type == .beginSeeking {
                let step = Double(SettingsManager.shared.seekInterval.rawValue)
                self?.playbackController?.seekBackward(seconds: step)
            }
            return .success
        }

        // 4. Change Playback Position (CarPlay Infotainment Scrubber Bar & Touch Seek)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.playbackController?.seekTo(seconds: posEvent.positionTime)
            return .success
        }
    }

    /// Dynamically updates the steering wheel and lock screen jump interval
    public func updateSeekInterval(_ seconds: Int) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: seconds)]
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: seconds)]
    }

    /// Updates the metadata visible on iPhone lock screen and Kia Seltos CarPlay display
    public func updateNowPlaying(
        title: String,
        channelOrSite: String,
        duration: Double = 0,
        elapsedTime: Double = 0,
        isPlaying: Bool = true
    ) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = channelOrSite
        info[MPMediaItemPropertyMediaType] = MPMediaType.any.rawValue

        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Keep background session alive during media playback
        if isPlaying {
            AudioSessionManager.shared.startBackgroundAudioKeepAlive()
        }
    }

    /// Clears Now Playing metadata when media terminates
    public func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AudioSessionManager.shared.stopBackgroundAudioKeepAlive()
    }
}

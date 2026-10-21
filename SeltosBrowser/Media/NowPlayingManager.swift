import Foundation
import MediaPlayer

/// Protocol for controlling active web media playback from remote CarPlay / steering wheel commands
public protocol MediaPlaybackControllable: AnyObject {
    func playMedia()
    func pauseMedia()
    func togglePlayPauseMedia()
    func seekForward(seconds: Double)
    func seekBackward(seconds: Double)
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

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.playbackController?.seekForward(seconds: 15)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.playbackController?.seekBackward(seconds: 15)
            return .success
        }
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

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clears Now Playing metadata when media terminates
    public func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

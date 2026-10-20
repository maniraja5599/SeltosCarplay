import Foundation
import AVFoundation

/// Coordinates system audio session for background playback and vehicle audio integration
public final class AudioSessionManager {
    public static let shared = AudioSessionManager()

    private init() {
        setupNotifications()
    }

    /// Configures audio session for background playback through CarPlay USB / Bluetooth
    public func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            print("[AudioSessionManager] Audio session successfully activated for media playback.")
        } catch {
            print("[AudioSessionManager] Failed to set audio session category: \(error.localizedDescription)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioSessionManager] Audio interruption began (e.g. phone call or car navigation prompt)")
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("[AudioSessionManager] Interruption ended with shouldResume.")
                }
            }
        @unknown default:
            break
        }
    }
}

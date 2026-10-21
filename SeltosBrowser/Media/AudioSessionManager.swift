import Foundation
import AVFoundation

/// Coordinates system audio session for background playback and vehicle audio integration
public final class AudioSessionManager {
    public static let shared = AudioSessionManager()

    private var keepAlivePlayer: AVAudioPlayer?
    private var isKeepAliveActive = false

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

    /// Starts a minimal silent audio loop to guarantee iOS never suspends WebKit or audio in background
    public func startBackgroundAudioKeepAlive() {
        guard !isKeepAliveActive else { return }
        isKeepAliveActive = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let silentData = Self.createSilentAudioWAV()
            do {
                self.keepAlivePlayer = try AVAudioPlayer(data: silentData)
                self.keepAlivePlayer?.numberOfLoops = -1 // Infinite loop
                self.keepAlivePlayer?.volume = 0.01 // Virtually inaudible
                self.keepAlivePlayer?.play()
                print("[AudioSessionManager] Background keep-alive audio loop started.")
            } catch {
                print("[AudioSessionManager] Keep-alive player error: \(error.localizedDescription)")
            }
        }
    }

    /// Stops the background keep-alive loop when media terminates
    public func stopBackgroundAudioKeepAlive() {
        isKeepAliveActive = false
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        print("[AudioSessionManager] Background keep-alive audio stopped.")
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
                    configureAudioSession()
                    keepAlivePlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }

    /// Generates a valid 1-second 44.1kHz mono silent WAV file in memory
    private static func createSilentAudioWAV() -> Data {
        var data = Data()
        // RIFF chunk descriptor
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        let chunkSize: UInt32 = 36 + 44100 * 2
        var cs = chunkSize.littleEndian
        data.append(Data(bytes: &cs, count: 4))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // "fmt " sub-chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let subchunk1Size: UInt32 = 16
        var sc1 = subchunk1Size.littleEndian
        data.append(Data(bytes: &sc1, count: 4))
        let audioFormat: UInt16 = 1 // PCM
        var af = audioFormat.littleEndian
        data.append(Data(bytes: &af, count: 2))
        let numChannels: UInt16 = 1 // Mono
        var nc = numChannels.littleEndian
        data.append(Data(bytes: &nc, count: 2))
        let sampleRate: UInt32 = 44100
        var sr = sampleRate.littleEndian
        data.append(Data(bytes: &sr, count: 4))
        let byteRate: UInt32 = 44100 * 2
        var br = byteRate.littleEndian
        data.append(Data(bytes: &br, count: 4))
        let blockAlign: UInt16 = 2
        var ba = blockAlign.littleEndian
        data.append(Data(bytes: &ba, count: 2))
        let bitsPerSample: UInt16 = 16
        var bps = bitsPerSample.littleEndian
        data.append(Data(bytes: &bps, count: 2))

        // "data" sub-chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        let subchunk2Size: UInt32 = 44100 * 2
        var sc2 = subchunk2Size.littleEndian
        data.append(Data(bytes: &sc2, count: 4))

        // Silent audio samples (all zeros)
        data.append(Data(count: Int(subchunk2Size)))
        return data
    }
}

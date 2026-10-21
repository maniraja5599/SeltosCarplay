import Foundation
import UIKit

/// Central coordinator managing both Local Hotspot and 4G/5G Cloud Relay remote control engines
public final class RemoteControlManager: ObservableObject {
    public static let shared = RemoteControlManager()

    public var localServer = LocalRemoteServer.shared
    public var cloudRelay = CloudRemoteRelay.shared

    @Published public private(set) var activeClientCount: Int = 0

    public init() {}

    public func startAll() {
        if SettingsManager.shared.isRemoteEnabled {
            localServer.start()
            cloudRelay.connect(with: SettingsManager.shared.remotePIN)
        }
    }

    public func stopAll() {
        localServer.stop()
        cloudRelay.disconnect()
    }

    public func updatePIN(_ newPIN: String) {
        SettingsManager.shared.remotePIN = newPIN
        cloudRelay.connect(with: newPIN)
    }

    /// Dispatches parsed remote control commands to the active browser view model
    public func executeCommand(action: String, jsonBody: String) {
        let viewModel = BrowserViewModel.shared

        // Parse optional parameters from jsonBody
        var params: [String: Any] = [:]
        if let data = jsonBody.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            params = parsed
        }

        switch action.lowercased() {
        case "play":
            viewModel.playMedia()

        case "pause":
            viewModel.pauseMedia()

        case "toggle":
            viewModel.togglePlayPauseMedia()

        case "seek":
            let delta = (params["delta"] as? Double) ?? (Double(SettingsManager.shared.seekInterval.rawValue))
            if delta >= 0 {
                viewModel.seekForward(seconds: delta)
            } else {
                viewModel.seekBackward(seconds: abs(delta))
            }

        case "load":
            if let query = params["query"] as? String, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.load(input: query)
            }

        case "home":
            viewModel.goToHome()

        case "back":
            viewModel.goBack()

        case "forward":
            viewModel.goForward()

        case "desktop":
            viewModel.toggleDesktopSite()

        case "fullscreen":
            viewModel.triggerVideoFullscreen()

        case "seekinterval":
            if let seconds = params["seconds"] as? Int,
               let interval = SeekInterval(rawValue: seconds) {
                SettingsManager.shared.seekInterval = interval
            }

        default:
            print("[RemoteControlManager] Unknown command received: \(action)")
        }
    }
}

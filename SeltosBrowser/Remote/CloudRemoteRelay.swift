import Foundation

/// Real-time cellular relay enabling remote control over 4G/5G mobile data without requiring a shared hotspot
public final class CloudRemoteRelay: ObservableObject {
    public static let shared = CloudRemoteRelay()

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var currentPIN: String = "5599"

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isIntentionalDisconnect = false

    public init() {
        self.session = URLSession(configuration: .default)
    }

    public func connect(with pin: String) {
        disconnect()
        self.currentPIN = pin
        self.isIntentionalDisconnect = false

        let urlString = "wss://ntfy.sh/kia_seltos_\(pin)/ws"
        guard let url = URL(string: urlString) else { return }

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        listenForMessages()
    }

    public func disconnect() {
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, !self.isIntentionalDisconnect else { return }

            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    self.isConnected = true
                }

                switch message {
                case .string(let text):
                    self.processMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.processMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue listening
                self.listenForMessages()

            case .failure(let error):
                print("[CloudRemoteRelay] WebSocket disconnected: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                // Auto-reconnect after 3 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, !self.isIntentionalDisconnect else { return }
                    self.connect(with: self.currentPIN)
                }
            }
        }
    }

    private func processMessage(_ rawText: String) {
        // ntfy.sh sends JSON lines: { "event": "message", "message": "{\"action\":\"...\"}" }
        guard let data = rawText.data(using: .utf8) else { return }

        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageContent = root["message"] as? String {
                if let payloadData = messageContent.data(using: .utf8),
                   let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                   let action = payload["action"] as? String {
                    DispatchQueue.main.async {
                        RemoteControlManager.shared.executeCommand(action: action, jsonBody: messageContent)
                    }
                }
            } else if let direct = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = direct["action"] as? String {
                DispatchQueue.main.async {
                    RemoteControlManager.shared.executeCommand(action: action, jsonBody: rawText)
                }
            }
        } catch {
            print("[CloudRemoteRelay] Failed to parse message: \(error.localizedDescription)")
        }
    }
}

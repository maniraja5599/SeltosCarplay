import Foundation
import Network

/// Lightweight embedded HTTP server serving the remote web app and accepting REST commands over local Wi-Fi / Hotspot
public final class LocalRemoteServer: ObservableObject {
    public static let shared = LocalRemoteServer()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var localIP: String = "127.0.0.1"
    @Published public private(set) var serverPort: UInt16 = 8080

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.seltos.remoteserver.queue", qos: .userInitiated)

    public var remoteURL: String {
        "http://\(localIP):\(serverPort)"
    }

    public init() {
        refreshIP()
    }

    public func start() {
        guard !isRunning else { return }
        refreshIP()

        do {
            let port = NWEndpoint.Port(rawValue: serverPort) ?? 8080
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: port)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            print("[LocalRemoteServer] Failed to start listener: \(error.localizedDescription)")
            isRunning = false
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    public func refreshIP() {
        localIP = Self.getLocalIPAddress() ?? "172.20.10.1"
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil,
                  let requestStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            self.processHTTPRequest(requestStr, connection: connection)
        }
    }

    private func processHTTPRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, contentType: "text/plain", body: "Bad Request")
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, contentType: "text/plain", body: "Bad Request")
            return
        }

        let method = parts[0].uppercased()
        let path = parts[1]

        // 1. Serve Touch Remote HTML
        if method == "GET" && (path == "/" || path.hasPrefix("/remote") || path.hasPrefix("/index")) {
            let html = RemoteWebPage.html(
                pin: SettingsManager.shared.remotePIN,
                currentSeek: SettingsManager.shared.seekInterval.rawValue
            )
            sendResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: html)
            return
        }

        // 2. Handle REST Command APIs
        if path.hasPrefix("/api/") {
            let command = String(path.dropFirst("/api/".count)).components(separatedBy: "?").first ?? ""
            let bodyText = lines.last ?? ""

            DispatchQueue.main.async {
                RemoteControlManager.shared.executeCommand(action: command, jsonBody: bodyText)
            }

            let responseJSON = "{\"status\":\"ok\",\"action\":\"\(command)\"}"
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: responseJSON)
            return
        }

        // Default: 404
        sendResponse(connection: connection, statusCode: 404, contentType: "text/plain", body: "Not Found")
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, contentType: String, body: String) {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : "Bad Request")
        let data = body.data(using: .utf8) ?? Data()
        let header = "HTTP/1.1 \(statusCode) \(statusText)\r\n" +
                     "Content-Type: \(contentType)\r\n" +
                     "Content-Length: \(data.count)\r\n" +
                     "Access-Control-Allow-Origin: *\r\n" +
                     "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                     "Access-Control-Allow-Headers: Content-Type\r\n" +
                     "Connection: close\r\n\r\n"

        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(data)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    /// Resolves active local Wi-Fi (en0) or Personal Hotspot (bridge100 / ap0) IPv4 address
    public static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "bridge100" || name == "ap0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if name == "en0" || name == "bridge100" {
                        return ip
                    }
                    address = ip
                }
            }
        }
        return address
    }
}

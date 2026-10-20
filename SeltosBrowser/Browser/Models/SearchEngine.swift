import Foundation

/// Supported search engines with URL formatting
public enum SearchEngine: String, CaseIterable, Identifiable, Codable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"
    case ecosia = "Ecosia"
    case brave = "Brave"

    public var id: String { rawValue }

    public var queryTemplate: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q="
        case .duckDuckGo:
            return "https://duckduckgo.com/?q="
        case .bing:
            return "https://www.bing.com/search?q="
        case .ecosia:
            return "https://www.ecosia.org/search?q="
        case .brave:
            return "https://search.brave.com/search?q="
        }
    }

    public func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(queryTemplate)\(encoded)")
    }
}

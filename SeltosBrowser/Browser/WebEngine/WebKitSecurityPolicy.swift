import Foundation

/// Security policy enforcer for URLs, certificates, and web navigation
public struct WebKitSecurityPolicy {

    /// Normalizes and secures user input from the address bar
    public static func resolveInput(_ rawInput: String, searchEngine: SearchEngine, enforceHTTPS: Bool) -> URL? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If it explicitly starts with a scheme
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            if scheme == "http" && enforceHTTPS {
                // Upgrade http to https
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"
                return components?.url
            }
            if scheme == "https" || scheme == "http" {
                return url
            }
            // Block dangerous schemes
            if ["javascript", "file", "data"].contains(scheme) {
                return nil
            }
        }

        // Check if input looks like a domain name (e.g. "youtube.com", "sub.domain.co.uk/path")
        let domainRegex = #"^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?::\d+)?(?:\/.*)?$"#
        let isDomainMatch = trimmed.range(of: domainRegex, options: .regularExpression) != nil

        if isDomainMatch {
            let scheme = enforceHTTPS ? "https://" : "https://"
            return URL(string: "\(scheme)\(trimmed)")
        }

        // Otherwise treat as search engine query
        return searchEngine.searchURL(for: trimmed)
    }

    /// Verifies whether a given URL is considered secure
    public static func isSecureURL(_ url: URL?) -> Bool {
        guard let url = url, let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https"
    }

    /// Determines if navigation should be allowed based on security criteria
    public static func isNavigationAllowed(for url: URL?) -> Bool {
        guard let url = url, let scheme = url.scheme?.lowercased() else { return false }
        // Only permit web protocols
        return scheme == "https" || scheme == "http" || scheme == "about"
    }
}

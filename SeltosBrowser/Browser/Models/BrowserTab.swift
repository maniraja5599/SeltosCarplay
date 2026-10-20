import Foundation

/// Represents a single browser tab session
public struct BrowserTab: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var url: URL?
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var isLoading: Bool
    public var estimatedProgress: Double
    public var errorMessage: String?
    public var isSecure: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "New Tab",
        url: URL? = nil,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isLoading: Bool = false,
        estimatedProgress: Double = 0.0,
        errorMessage: String? = nil,
        isSecure: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.errorMessage = errorMessage
        self.isSecure = isSecure
        self.createdAt = createdAt
    }

    public var displayTitle: String {
        if !title.isEmpty && title != "New Tab" {
            return title
        }
        if let host = url?.host {
            return host
        }
        return "New Tab"
    }

    public var isHome: Bool {
        return url == nil
    }
}

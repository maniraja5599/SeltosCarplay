import Foundation

/// Represents a visited website record
public struct HistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let urlString: String
    public let visitedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.isEmpty ? urlString : title
        self.urlString = urlString
        self.visitedAt = visitedAt
    }

    public var url: URL? {
        URL(string: urlString)
    }

    public var host: String {
        url?.host ?? urlString
    }
}

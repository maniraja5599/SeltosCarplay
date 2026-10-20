import Foundation

/// Represents a user bookmark or favorite website
public struct Bookmark: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var urlString: String
    public var iconName: String
    public var isFavorite: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        iconName: String = "globe",
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.iconName = iconName
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    public var url: URL? {
        URL(string: urlString)
    }

    public var host: String {
        url?.host ?? urlString
    }
}

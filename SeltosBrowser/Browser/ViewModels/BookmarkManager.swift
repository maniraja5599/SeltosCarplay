import Foundation
import Combine

/// Manages local persistence and modification of user bookmarks and favorites
public final class BookmarkManager: ObservableObject {
    public static let shared = BookmarkManager()

    @Published public private(set) var bookmarks: [Bookmark] = []
    
    private let fileName = "bookmarks.json"
    private let fileQueue = DispatchQueue(label: "com.seltosbrowser.bookmarks.queue", qos: .utility)

    public init() {
        loadBookmarks()
    }

    public var favorites: [Bookmark] {
        bookmarks.filter { $0.isFavorite }
    }

    public func addBookmark(title: String, urlString: String, iconName: String = "globe", isFavorite: Bool = false) {
        let newBookmark = Bookmark(
            title: title.isEmpty ? urlString : title,
            urlString: urlString,
            iconName: iconName,
            isFavorite: isFavorite
        )
        bookmarks.append(newBookmark)
        saveBookmarks()
    }

    public func removeBookmark(at indexSet: IndexSet) {
        bookmarks.remove(atOffsets: indexSet)
        saveBookmarks()
    }

    public func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }

    public func toggleFavorite(for id: UUID) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            bookmarks[index].isFavorite.toggle()
            saveBookmarks()
        }
    }

    public func isBookmarked(urlString: String) -> Bool {
        bookmarks.contains { $0.urlString == urlString }
    }

    private func getDocumentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getFileURL() -> URL {
        getDocumentsURL().appendingPathComponent(fileName)
    }

    private func loadBookmarks() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Populate defaults on first launch
            self.bookmarks = Self.defaultBookmarks
            saveBookmarks()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Bookmark].self, from: data)
            self.bookmarks = decoded
        } catch {
            print("[BookmarkManager] Error decoding bookmarks: \(error.localizedDescription)")
            self.bookmarks = Self.defaultBookmarks
        }
    }

    private func saveBookmarks() {
        let itemsToSave = bookmarks
        let url = getFileURL()
        fileQueue.async {
            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
            } catch {
                print("[BookmarkManager] Failed to save bookmarks: \(error.localizedDescription)")
            }
        }
    }

    public static var defaultBookmarks: [Bookmark] {
        [
            Bookmark(
                title: "YouTube",
                urlString: "https://m.youtube.com",
                iconName: "play.rectangle.fill",
                isFavorite: true
            ),
            Bookmark(
                title: "Google",
                urlString: "https://www.google.com",
                iconName: "magnifyingglass",
                isFavorite: true
            ),
            Bookmark(
                title: "Wikipedia",
                urlString: "https://en.m.wikipedia.org",
                iconName: "book.fill",
                isFavorite: true
            ),
            Bookmark(
                title: "GitHub",
                urlString: "https://github.com",
                iconName: "chevron.left.forwardslash.chevron.right",
                isFavorite: true
            ),
            Bookmark(
                title: "DuckDuckGo",
                urlString: "https://duckduckgo.com",
                iconName: "shield.checkerboard",
                isFavorite: true
            )
        ]
    }
}

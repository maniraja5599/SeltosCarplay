import Foundation
import Combine

/// Manages local browsing history persistence and privacy deletion
public final class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()

    @Published public private(set) var historyItems: [HistoryItem] = []

    private let fileName = "history.json"
    private let fileQueue = DispatchQueue(label: "com.seltosbrowser.history.queue", qos: .utility)
    private let maxHistoryEntries = 500

    public init() {
        loadHistory()
    }

    public func addEntry(title: String, urlString: String) {
        guard !urlString.isEmpty, urlString != "about:blank" else { return }

        // Deduplicate recent identical URLs if added within 5 seconds
        if let first = historyItems.first, first.urlString == urlString,
           Date().timeIntervalSince(first.visitedAt) < 5 {
            return
        }

        let item = HistoryItem(title: title, urlString: urlString, visitedAt: Date())
        historyItems.insert(item, at: 0)

        if historyItems.count > maxHistoryEntries {
            historyItems = Array(historyItems.prefix(maxHistoryEntries))
        }

        saveHistory()
    }

    public func removeEntry(at indexSet: IndexSet) {
        historyItems.remove(atOffsets: indexSet)
        saveHistory()
    }

    public func clearAllHistory() {
        historyItems.removeAll()
        saveHistory()
    }

    private func getDocumentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getFileURL() -> URL {
        getDocumentsURL().appendingPathComponent(fileName)
    }

    private func loadHistory() {
        let url = getFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([HistoryItem].self, from: data)
            self.historyItems = decoded
        } catch {
            print("[HistoryManager] Failed to load history: \(error.localizedDescription)")
            self.historyItems = []
        }
    }

    private func saveHistory() {
        let itemsToSave = historyItems
        let url = getFileURL()
        fileQueue.async {
            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
            } catch {
                print("[HistoryManager] Failed to save history: \(error.localizedDescription)")
            }
        }
    }
}

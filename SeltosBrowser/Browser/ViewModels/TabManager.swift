import Foundation
import Combine

/// Manages multi-tab browsing sessions
public final class TabManager: ObservableObject {
    public static let shared = TabManager()

    @Published public var tabs: [BrowserTab] = []
    @Published public var activeTabId: UUID

    public init() {
        let initialTab = BrowserTab()
        self.tabs = [initialTab]
        self.activeTabId = initialTab.id
    }

    public var activeTab: BrowserTab {
        get {
            tabs.first(where: { $0.id == activeTabId }) ?? tabs.first ?? BrowserTab()
        }
        set {
            if let index = tabs.firstIndex(where: { $0.id == newValue.id }) {
                tabs[index] = newValue
            }
        }
    }

    public func createNewTab(with url: URL? = nil, title: String = "New Tab") -> UUID {
        let newTab = BrowserTab(title: title, url: url)
        tabs.append(newTab)
        activeTabId = newTab.id
        return newTab.id
    }

    public func closeTab(id: UUID) {
        guard tabs.count > 1 else {
            // Keep at least one tab open; reset it to Home
            if let index = tabs.firstIndex(where: { $0.id == id }) {
                tabs[index] = BrowserTab()
                activeTabId = tabs[index].id
            }
            return
        }

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            if activeTabId == id {
                // Switch to adjacent tab
                let newIndex = max(0, index - 1)
                activeTabId = tabs[newIndex].id
            }
        }
    }

    public func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    public func updateActiveTab(
        title: String? = nil,
        url: URL? = nil,
        canGoBack: Bool? = nil,
        canGoForward: Bool? = nil,
        isLoading: Bool? = nil,
        estimatedProgress: Double? = nil,
        errorMessage: String? = nil,
        isSecure: Bool? = nil
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }

        if let title = title { tabs[index].title = title }
        if let url = url { tabs[index].url = url }
        if let canGoBack = canGoBack { tabs[index].canGoBack = canGoBack }
        if let canGoForward = canGoForward { tabs[index].canGoForward = canGoForward }
        if let isLoading = isLoading { tabs[index].isLoading = isLoading }
        if let estimatedProgress = estimatedProgress { tabs[index].estimatedProgress = estimatedProgress }
        tabs[index].errorMessage = errorMessage
        if let isSecure = isSecure { tabs[index].isSecure = isSecure }
    }
}

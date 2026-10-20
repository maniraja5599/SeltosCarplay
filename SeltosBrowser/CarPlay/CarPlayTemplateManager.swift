import Foundation
import CarPlay

/// Constructs and coordinates official CarPlay templates for the Kia Seltos head unit
public final class CarPlayTemplateManager {
    public static let shared = CarPlayTemplateManager()

    private weak var interfaceController: CPInterfaceController?

    private init() {}

    public func setInterfaceController(_ controller: CPInterfaceController) {
        self.interfaceController = controller
    }

    /// Creates the root CPTabBarTemplate for the vehicle display
    public func createRootTemplate() -> CPTabBarTemplate {
        let favoritesTab = makeFavoritesTemplate()
        let recentsTab = makeRecentHistoryTemplate()
        let statusTab = makeVehicleStatusTemplate()

        let tabBar = CPTabBarTemplate(templates: [favoritesTab, recentsTab, statusTab])
        return tabBar
    }

    // MARK: - Template Generators

    private func makeFavoritesTemplate() -> CPListTemplate {
        let bookmarks = BookmarkManager.shared.bookmarks
        var items: [CPListItem] = []

        for bookmark in bookmarks {
            let item = CPListItem(
                text: bookmark.title,
                detailText: bookmark.host,
                image: UIImage(systemName: bookmark.iconName)
            )
            item.handler = { [weak self] _, completion in
                self?.handleBookmarkSelection(bookmark)
                completion()
            }
            items.append(item)
        }

        if items.isEmpty {
            let emptyItem = CPListItem(text: "No Bookmarks", detailText: "Add favorites from your iPhone")
            items.append(emptyItem)
        }

        let section = CPListSection(items: items, header: "Web & Media Bookmarks", sectionIndexTitle: nil)
        let listTemplate = CPListTemplate(title: "Favorites", sections: [section])
        listTemplate.tabImage = UIImage(systemName: "star.fill")
        return listTemplate
    }

    private func makeRecentHistoryTemplate() -> CPListTemplate {
        let history = HistoryManager.shared.historyItems.prefix(20)
        var items: [CPListItem] = []

        for item in history {
            let listItem = CPListItem(
                text: item.title,
                detailText: item.host,
                image: UIImage(systemName: "clock.arrow.circlepath")
            )
            listItem.handler = { [weak self] _, completion in
                self?.handleHistorySelection(item)
                completion()
            }
            items.append(listItem)
        }

        if items.isEmpty {
            let emptyItem = CPListItem(text: "No Recent History", detailText: "Visit websites on iPhone first")
            items.append(emptyItem)
        }

        let section = CPListSection(items: items, header: "Recently Visited", sectionIndexTitle: nil)
        let listTemplate = CPListTemplate(title: "Recents", sections: [section])
        listTemplate.tabImage = UIImage(systemName: "clock.fill")
        return listTemplate
    }

    private func makeVehicleStatusTemplate() -> CPInformationTemplate {
        let isMoving = CarPlaySafetyMonitor.shared.isVehicleMoving

        let statusItem = CPInformationItem(
            title: "Vehicle State",
            detail: isMoving ? "Driving / In Motion" : "Parked"
        )
        let safetyItem = CPInformationItem(
            title: "Safety Standard",
            detail: "Audio media controls active. Web browsing restricted while driving."
        )
        let carplayInfo = CPInformationItem(
            title: "Kia Seltos Connection",
            detail: "USB Wired CarPlay Active"
        )

        let infoTemplate = CPInformationTemplate(
            title: "Safety",
            layout: .leading,
            items: [statusItem, safetyItem, carplayInfo],
            actions: []
        )
        infoTemplate.tabImage = UIImage(systemName: "shield.lefthalf.filled")
        return infoTemplate
    }

    // MARK: - Action Handlers

    private func handleBookmarkSelection(_ bookmark: Bookmark) {
        DispatchQueue.main.async {
            BrowserViewModel.shared.loadBookmark(bookmark)
            // Push Now Playing template if media is anticipated
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }

    private func handleHistorySelection(_ item: HistoryItem) {
        DispatchQueue.main.async {
            BrowserViewModel.shared.load(input: item.urlString)
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }
}

import XCTest
@testable import SeltosBrowser

final class TabManagerTests: XCTestCase {

    func testInitialTabCreatedOnLaunch() {
        let manager = TabManager()
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.activeTab.displayTitle, "New Tab")
    }

    func testCreateNewTabUpdatesActiveTab() {
        let manager = TabManager()
        let testURL = URL(string: "https://m.youtube.com")
        let tabId = manager.createNewTab(with: testURL, title: "YouTube")

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.activeTabId, tabId)
        XCTAssertEqual(manager.activeTab.url, testURL)
    }

    func testCloseTabSwitchesToAdjacentTab() {
        let manager = TabManager()
        let tab1Id = manager.activeTabId
        let tab2Id = manager.createNewTab(with: URL(string: "https://google.com"), title: "Google")

        XCTAssertEqual(manager.activeTabId, tab2Id)
        manager.closeTab(id: tab2Id)

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.activeTabId, tab1Id)
    }

    func testClosingLastTabResetsToHomeWithoutCrashing() {
        let manager = TabManager()
        let soleTabId = manager.activeTabId

        manager.closeTab(id: soleTabId)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertTrue(manager.activeTab.isHome)
    }
}

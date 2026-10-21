import SwiftUI

@main
struct SeltosBrowserApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            BrowserContainerView()
        }
    }
}

import SwiftUI
import WebKit

/// Main full-screen iPhone browser container view coordinating navigation, WebKit, and controls
public struct BrowserContainerView: View {
    @StateObject private var viewModel = BrowserViewModel.shared
    @State private var showShareSheet: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Address / Search Bar Header
            HStack(spacing: 12) {
                AddressBarView(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .background(Color(.systemBackground).ignoresSafeArea(edges: .top))

            // Navigation Loading Progress Bar
            if viewModel.activeTab.isLoading {
                ProgressView(value: viewModel.activeTab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.accentColor)
                    .frame(height: 2)
            } else {
                Divider()
            }

            // Main View Area: Home vs Error vs Web Content
            ZStack {
                if viewModel.activeTab.isHome {
                    HomeFavoritesView(viewModel: viewModel)
                } else if let error = viewModel.activeTab.errorMessage {
                    WebErrorView(
                        errorMessage: error,
                        onRetry: { viewModel.reload() },
                        onGoHome: { viewModel.goToHome() }
                    )
                } else {
                    WebViewContainer(viewModel: viewModel, tabId: viewModel.tabManager.activeTabId)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom Navigation Toolbar
            bottomToolbar
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $viewModel.showTabSwitcher) {
            TabSwitcherView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBookmarksSheet) {
            BookmarksSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showHistorySheet) {
            HistorySheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            SettingsSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.activeTab.url {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 4) {
            // Back
            Button(action: {
                viewModel.goBack()
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoBack)
            .frame(maxWidth: .infinity)

            // Forward
            Button(action: {
                viewModel.goForward()
            }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 17, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoForward)
            .frame(maxWidth: .infinity)

            // Home
            Button(action: {
                viewModel.goToHome()
            }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // Share Page
            Button(action: {
                if viewModel.activeTab.url != nil {
                    showShareSheet = true
                }
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
            .disabled(viewModel.activeTab.isHome)
            .frame(maxWidth: .infinity)

            // Desktop / Mobile Quick Toggle
            Button(action: {
                viewModel.settingsManager.requestDesktopSites.toggle()
                viewModel.reload()
            }) {
                Image(systemName: viewModel.settingsManager.requestDesktopSites ? "desktopcomputer" : "iphone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(viewModel.settingsManager.requestDesktopSites ? .accentColor : .primary)
            }
            .disabled(viewModel.activeTab.isHome)
            .frame(maxWidth: .infinity)

            // Bookmarks
            Button(action: {
                viewModel.showBookmarksSheet = true
            }) {
                Image(systemName: "book")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // Tab Switcher Button
            Button(action: {
                viewModel.showTabSwitcher = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary, lineWidth: 1.8)
                        .frame(width: 20, height: 20)

                    Text("\(viewModel.tabManager.tabs.count)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)

            // Settings
            Button(action: {
                viewModel.showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
    }
}

/// UIActivityViewController representable for native iOS sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

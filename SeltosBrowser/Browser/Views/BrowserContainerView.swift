import SwiftUI

/// Main full-screen iPhone browser container view coordinating navigation, WebKit, and controls
public struct BrowserContainerView: View {
    @StateObject private var viewModel = BrowserViewModel.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Address / Search Bar Header
            HStack(spacing: 12) {
                AddressBarView(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color(.systemBackground))

            // Navigation Loading Progress Bar
            if viewModel.activeTab.isLoading {
                ProgressView(value: viewModel.activeTab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
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
                        .edgesIgnoringSafeArea(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom Navigation Toolbar
            bottomToolbar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
        }
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
    }

    private var bottomToolbar: some View {
        HStack {
            // Back
            Button(action: {
                viewModel.goBack()
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoBack)
            .frame(maxWidth: .infinity)

            // Forward
            Button(action: {
                viewModel.goForward()
            }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoForward)
            .frame(maxWidth: .infinity)

            // Home
            Button(action: {
                viewModel.goToHome()
            }) {
                Image(systemName: "house")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // Bookmarks
            Button(action: {
                viewModel.showBookmarksSheet = true
            }) {
                Image(systemName: "book")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // History
            Button(action: {
                viewModel.showHistorySheet = true
            }) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // Tab Switcher Button
            Button(action: {
                viewModel.showTabSwitcher = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary, lineWidth: 1.8)
                        .frame(width: 22, height: 22)

                    Text("\(viewModel.tabManager.tabs.count)")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)

            // Settings
            Button(action: {
                viewModel.showSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
    }
}

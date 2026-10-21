import SwiftUI
import WebKit

/// Main full-screen iPhone browser container view coordinating navigation, WebKit, and controls
public struct BrowserContainerView: View {
    @StateObject private var viewModel = BrowserViewModel.shared
    @State private var showShareSheet: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Address / Search Bar Header (hidden in full-screen video mode)
            if !viewModel.isFullscreenVideo {
                HStack(spacing: 12) {
                    AddressBarView(viewModel: viewModel)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
                .transition(.move(edge: .top).combined(with: .opacity))

                // Navigation Loading Progress Bar
                if viewModel.activeTab.isLoading {
                    ProgressView(value: viewModel.activeTab.estimatedProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.accentColor)
                        .frame(height: 2)
                } else {
                    Divider()
                }
            }

            // Main View Area: Persistent WebKit + Home Favorites Overlay
            ZStack {
                // Persistent WKWebView for the active tab (keeps WebKit alive across navigation)
                WebViewContainer(viewModel: viewModel, tabId: viewModel.tabManager.activeTabId)
                    .opacity(viewModel.activeTab.isHome ? 0 : 1)
                    .allowsHitTesting(!viewModel.activeTab.isHome)

                if viewModel.activeTab.isHome {
                    HomeFavoritesView(viewModel: viewModel)
                        .transition(.opacity)
                } else if let error = viewModel.activeTab.errorMessage {
                    WebErrorView(
                        errorMessage: error,
                        onRetry: { viewModel.reload() },
                        onGoHome: { viewModel.goToHome() }
                    )
                }

                // Overlay control when video enters fullscreen
                if viewModel.isFullscreenVideo {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    viewModel.isFullscreenVideo = false
                                }
                            }) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.65))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Navigation Toolbar (hidden in full-screen video mode)
            if !viewModel.isFullscreenVideo {
                Divider()

                bottomToolbar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            SettingsSheetView(viewModel: viewModel, onShareRequested: {
                showShareSheet = true
            })
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.activeTab.url {
                ShareSheet(activityItems: [url])
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isFullscreenVideo)
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeTab.isHome)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            // 1. Back
            Button(action: {
                viewModel.goBack()
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoBack)
            .frame(maxWidth: .infinity)

            // 2. Forward
            Button(action: {
                viewModel.goForward()
            }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 18, weight: .semibold))
            }
            .disabled(!viewModel.activeTab.canGoForward)
            .frame(maxWidth: .infinity)

            // 3. Home Button (returns instantly to Favorites)
            Button(action: {
                withAnimation {
                    viewModel.goToHome()
                }
            }) {
                Image(systemName: viewModel.activeTab.isHome ? "house.fill" : "house")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(viewModel.activeTab.isHome ? .accentColor : .primary)
            }
            .frame(maxWidth: .infinity)

            // 4. Bookmarks
            Button(action: {
                viewModel.showBookmarksSheet = true
            }) {
                Image(systemName: "book.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            // 5. Tab Switcher
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

            // 6. Settings
            Button(action: {
                viewModel.showSettingsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
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

import SwiftUI
import WebKit

/// Settings view providing page actions, Bookmarks access, Desktop mode, and car integration status
public struct SettingsSheetView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var onShareRequested: (() -> Void)? = nil

    @State private var showWipeConfirmation = false
    @State private var isClearingData = false
    @State private var showBookmarkAddedAlert = false

    public init(viewModel: BrowserViewModel, onShareRequested: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onShareRequested = onShareRequested
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Bookmarks & Favorites Access (Moved to Settings as requested)
                Section(header: Text("Bookmarks & Favorites")) {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showBookmarksSheet = true
                        }
                    }) {
                        HStack {
                            Label("Open Bookmarks & Favorites", systemImage: "star.fill")
                                .foregroundColor(.accentColor)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Current Page Quick Actions (Available when a website is open)
                if !viewModel.isHome {
                    Section(header: Text("Current Page")) {
                        // 1. Share
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShareRequested?()
                            }
                        }) {
                            Label("Share Page", systemImage: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }

                        // 2. Reader Mode
                        Toggle(isOn: Binding(
                            get: { viewModel.isReaderModeActive },
                            set: { _ in viewModel.toggleReaderMode() }
                        )) {
                            Label("Reader Mode", systemImage: "doc.text.fill")
                        }

                        // 3. Request Desktop Site
                        Toggle(isOn: Binding(
                            get: { settings.requestDesktopSites },
                            set: { _ in viewModel.toggleDesktopSite() }
                        )) {
                            Label("Request Desktop Site", systemImage: "desktopcomputer")
                        }

                        // 4. Force Video Fullscreen
                        Button(action: {
                            viewModel.triggerVideoFullscreen()
                            dismiss()
                        }) {
                            Label("Expand Video to Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.primary)
                        }

                        // 5. Add to Bookmarks
                        Button(action: {
                            if let url = viewModel.activeTab.url {
                                viewModel.bookmarkManager.addBookmark(
                                    title: viewModel.activeTab.title,
                                    urlString: url.absoluteString,
                                    iconName: "globe",
                                    isFavorite: false
                                )
                                showBookmarkAddedAlert = true
                            }
                        }) {
                            Label("Add Page to Bookmarks", systemImage: "bookmark.fill")
                                .foregroundColor(.primary)
                        }
                    }
                }

                // Search Engine Configuration
                Section(header: Text("Search Engine")) {
                    Picker("Default Engine", selection: $settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                }

                // Web Capabilities & Security
                Section(header: Text("Security & Privacy")) {
                    Toggle("Enforce HTTPS Only", isOn: $settings.enforceHTTPSOnly)
                    Toggle("Block Intrusive Ads & Trackers", isOn: $settings.blockAdsAndTrackers)
                    Toggle("Block Popups", isOn: $settings.blockPopups)
                }

                // Media & Vehicle Playback
                Section(
                    header: Text("Vehicle Audio & CarPlay"),
                    footer: Text("Audio playback stays active when screen is locked or when running via Apple CarPlay in your Kia Seltos.")
                ) {
                    Toggle("Allow Inline Media Playback", isOn: $settings.allowInlineMediaPlayback)
                    HStack {
                        Label("Steering Wheel Controls", systemImage: "steeringwheel")
                        Spacer()
                        Text("Seek ±15s / Pause")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }

                // Privacy & Storage Wipe
                Section(
                    header: Text("Privacy & Storage"),
                    footer: Text("Clears all cached web files, HTTP cookies, local storage databases, and browsing history from this iPhone.")
                ) {
                    Button(role: .destructive, action: {
                        showWipeConfirmation = true
                    }) {
                        HStack {
                            if isClearingData {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                            Text("Clear All Browsing Data & Cookies")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isClearingData)
                }

                // About & Custom Logo
                Section(header: Text("About Kia Browser")) {
                    HStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kia Browser")
                                .font(.headline)
                            Text("Electric Edition • Build 3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("Target Vehicle")
                        Spacer()
                        Text("Kia Seltos (USB CarPlay)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("CarPlay Integration")
                        Spacer()
                        Text("Audio & Media Session")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Search Provider")
                        Spacer()
                        Text("Google Voice & Web")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Browsing Data?", isPresented: $showWipeConfirmation) {
                Button("Wipe Everything", role: .destructive) {
                    isClearingData = true
                    viewModel.clearAllBrowsingData {
                        isClearingData = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all cached pages, cookies, local storage, and history.")
            }
            .alert("Bookmark Added", isPresented: $showBookmarkAddedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Page has been added to your Bookmarks.")
            }
        }
    }
}

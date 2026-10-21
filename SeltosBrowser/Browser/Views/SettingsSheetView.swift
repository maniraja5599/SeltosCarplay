import SwiftUI
import WebKit

/// Settings view providing page actions, Remote Control setup, Seek Interval configuration, and privacy controls
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
                // 1. Wireless Remote Control Section (Hotspot + 4G/5G Relay)
                Section(header: Text("Wireless Car Remote")) {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showRemoteControlSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open Remote Control")
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                Text("PIN: \(settings.remotePIN) • QR Code & Hotspot")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 2. Bookmarks & Favorites Access
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

                // 3. Current Page Quick Actions (Available when a website is open)
                if !viewModel.isHome {
                    Section(header: Text("Current Page")) {
                        // Share
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShareRequested?()
                            }
                        }) {
                            Label("Share Page", systemImage: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }

                        // Reader Mode
                        Toggle(isOn: Binding(
                            get: { viewModel.isReaderModeActive },
                            set: { _ in viewModel.toggleReaderMode() }
                        )) {
                            Label("Reader Mode", systemImage: "doc.text.fill")
                        }

                        // Request Desktop Site
                        Toggle(isOn: Binding(
                            get: { settings.requestDesktopSites },
                            set: { _ in viewModel.toggleDesktopSite() }
                        )) {
                            Label("Request Desktop Site", systemImage: "desktopcomputer")
                        }

                        // Force Video Fullscreen
                        Button(action: {
                            viewModel.triggerVideoFullscreen()
                            dismiss()
                        }) {
                            Label("Expand Video to Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.primary)
                        }

                        // Add to Bookmarks
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

                // 4. Media Seek Interval & Steering Wheel Controls
                Section(
                    header: Text("Media Playback & Steering Wheel"),
                    footer: Text("Sets how many seconds media skips when pressing steering wheel buttons or the wireless remote.")
                ) {
                    Picker("Seek Jump Interval", selection: $settings.seekInterval) {
                        ForEach(SeekInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }

                    Toggle("Allow Inline Media Playback", isOn: $settings.allowInlineMediaPlayback)
                }

                // 5. Search Engine Configuration
                Section(header: Text("Search Engine")) {
                    Picker("Default Engine", selection: $settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                }

                // 6. Web Capabilities & Security
                Section(header: Text("Security & Privacy")) {
                    Toggle("Enforce HTTPS Only", isOn: $settings.enforceHTTPSOnly)
                    Toggle("Block Intrusive Ads & Trackers", isOn: $settings.blockAdsAndTrackers)
                    Toggle("Block Popups", isOn: $settings.blockPopups)
                }

                // 7. Privacy & Storage Wipe
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

                // 8. About & Custom Logo
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
                            Text("Electric Edition • Build 5")
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
                        Text("Wireless Remote")
                        Spacer()
                        Text("Hotspot + 4G/5G Hybrid")
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

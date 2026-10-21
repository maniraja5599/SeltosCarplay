import SwiftUI

/// Settings view providing search engine configuration, privacy controls, and full data clearing
public struct SettingsSheetView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWipeConfirmation = false
    @State private var isClearingData = false
    @State private var showWipeSuccessAlert = false

    public var body: some View {
        NavigationStack {
            Form {
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
                    Toggle("Request Desktop Sites", isOn: $settings.requestDesktopSites)
                }

                // Media & Playback
                Section(header: Text("Media Playback"), footer: Text("Inline media playback allows YouTube videos to play directly on web pages and enables Picture-in-Picture on iPhone.")) {
                    Toggle("Allow Inline Media Playback", isOn: $settings.allowInlineMediaPlayback)
                }

                // Privacy & Data Destruction
                Section(
                    header: Text("Privacy & Storage"),
                    footer: Text("Clears all cached web files, HTTP cookies, local storage databases, and local history from this device.")
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

                // About & Vehicle Integration
                Section(header: Text("About")) {
                    HStack {
                        Text("Application")
                        Spacer()
                        Text("Kia Browser")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Vehicle")
                        Spacer()
                        Text("Kia Seltos (USB CarPlay)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("CarPlay Integration")
                        Spacer()
                        Text("Media / Audio Template")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
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
                        showWipeSuccessAlert = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all cookies, cached files, local storage, and history records.")
            }
            .alert("Data Cleared", isPresented: $showWipeSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All website data, cookies, and local history have been removed.")
            }
        }
    }
}

import SwiftUI

/// Sheet displaying saved bookmarks and allowing current page bookmarking
public struct BookmarksSheetView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                // Add Current Page Section
                if let currentURL = viewModel.activeTab.url, !viewModel.activeTab.isHome {
                    Section {
                        Button(action: {
                            viewModel.bookmarkManager.addBookmark(
                                title: viewModel.activeTab.displayTitle,
                                urlString: currentURL.absoluteString,
                                iconName: "bookmark.fill",
                                isFavorite: false
                            )
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Bookmark Current Page")
                                    .foregroundColor(.primary)
                            }
                        }
                        .disabled(viewModel.bookmarkManager.isBookmarked(urlString: currentURL.absoluteString))
                    }
                }

                // Bookmarks List
                Section(header: Text("All Bookmarks")) {
                    if viewModel.bookmarkManager.bookmarks.isEmpty {
                        Text("No bookmarks saved yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.bookmarkManager.bookmarks) { bookmark in
                            Button(action: {
                                viewModel.loadBookmark(bookmark)
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: bookmark.iconName)
                                        .frame(width: 24)
                                        .foregroundColor(.accentColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(bookmark.host)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if bookmark.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.bookmarkManager.removeBookmark(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

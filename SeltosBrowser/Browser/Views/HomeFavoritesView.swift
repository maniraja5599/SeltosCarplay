import SwiftUI

/// Default home page displaying pinned favorites, shortcuts, and car connection status
public struct HomeFavoritesView: View {
    @ObservedObject var viewModel: BrowserViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 20)
    ]

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header Banner
                VStack(spacing: 8) {
                    Image(systemName: "car.side.front.open.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)

                    Text("Kia Seltos Private Browser")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("Secure browsing with CarPlay media integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 36)

                // Favorites Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Favorites")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(viewModel.bookmarkManager.favorites) { bookmark in
                            Button(action: {
                                viewModel.loadBookmark(bookmark)
                            }) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                                        Image(systemName: bookmark.iconName)
                                            .font(.system(size: 28))
                                            .foregroundColor(iconColor(for: bookmark.title))
                                    }

                                    Text(bookmark.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // In-Car Experience Tips
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Vehicle Audio & CarPlay Info")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("When connected to your Kia Seltos via USB, playing audio or YouTube media on this browser will stream directly through your car's audio system. You can control playback via steering wheel buttons and the CarPlay Now Playing screen.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func iconColor(for title: String) -> Color {
        switch title.lowercased() {
        case "youtube", "netflix", "youtube music": return .red
        case "google", "prime video": return .blue
        case "hotstar": return .indigo
        case "spotify", "chatgpt": return .green
        case "apple music": return .pink
        case "twitch", "github": return .purple
        case "duckduckgo", "reddit": return .orange
        case "wikipedia": return .primary
        default: return .accentColor
        }
    }
}

/// Subtle spring animation on tap
public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

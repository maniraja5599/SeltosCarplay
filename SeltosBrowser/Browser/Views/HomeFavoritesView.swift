import SwiftUI

/// Default home page displaying pinned favorites, shortcuts, remote access banner, and custom logo badge
public struct HomeFavoritesView: View {
    @ObservedObject var viewModel: BrowserViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 78, maximum: 96), spacing: 18)
    ]

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Custom Logo Badge (No text)
                VStack(spacing: 0) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 14)

                // Wireless Remote Quick Access Banner
                Button(action: {
                    viewModel.showRemoteControlSheet = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Android Wireless Remote")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("PIN: \(viewModel.settingsManager.remotePIN) • Tap to view QR Code")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "qrcode")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                }
                .buttonStyle(ScaleButtonStyle())

                // Favorites Grid Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Favorites & Media")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.bookmarkManager.favorites) { bookmark in
                            Button(action: {
                                viewModel.loadBookmark(bookmark)
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 62, height: 62)
                                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                                        Image(systemName: bookmark.iconName)
                                            .font(.system(size: 26))
                                            .foregroundColor(iconColor(for: bookmark.title))
                                    }

                                    Text(bookmark.title)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // In-Car Audio & Steering Wheel Tips
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "car.side.fill")
                            .foregroundColor(.blue)
                        Text("Kia Seltos CarPlay Audio Active")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("Connected via USB: Media audio streams directly through car speakers. Seek jump: \(viewModel.settingsManager.seekInterval.title).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(14)
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
        case "google", "prime video", "google maps": return .blue
        case "hotstar": return .indigo
        case "jiocinema": return .pink
        case "zee5": return .purple
        case "spotify", "chatgpt", "cricbuzz": return .green
        case "apple music", "instagram": return .pink
        case "reddit", "amazon": return .orange
        case "fast.com": return .teal
        case "wikipedia", "x (twitter)": return .primary
        default: return .accentColor
        }
    }
}

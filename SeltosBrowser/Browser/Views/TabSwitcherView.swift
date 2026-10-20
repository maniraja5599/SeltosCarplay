import SwiftUI

/// Grid view allowing users to switch, close, or create new browser tabs
public struct TabSwitcherView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.tabManager.tabs) { tab in
                        ZStack(alignment: .topTrailing) {
                            Button(action: {
                                viewModel.tabManager.selectTab(id: tab.id)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: tab.isSecure ? "lock.fill" : "globe")
                                            .font(.caption2)
                                            .foregroundColor(tab.isSecure ? .green : .secondary)

                                        Text(tab.displayTitle)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }

                                    // Tab Thumbnail Placeholder
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 120)
                                        .overlay(
                                            VStack(spacing: 6) {
                                                Image(systemName: tab.isHome ? "house.fill" : "safari.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.secondary)
                                                if let host = tab.url?.host {
                                                    Text(host)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        )
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(tab.id == viewModel.tabManager.activeTabId ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }

                            // Close Button
                            Button(action: {
                                viewModel.closeTab(id: tab.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                                    .background(Circle().fill(Color(.systemBackground)))
                            }
                            .padding(6)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tabs (\(viewModel.tabManager.tabs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.addNewTab()
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New Tab")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

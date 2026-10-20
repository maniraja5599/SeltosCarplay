import SwiftUI

/// Sheet displaying local browsing history with individual deletion and complete wipe
public struct HistorySheetView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.historyManager.historyItems.isEmpty {
                    Text("No browsing history found.")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.historyManager.historyItems) { item in
                        Button(action: {
                            viewModel.load(input: item.urlString)
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                HStack {
                                    Text(item.host)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(dateFormatter.string(from: item.visitedAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.historyManager.removeEntry(at: indexSet)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.historyManager.historyItems.isEmpty {
                        Button(role: .destructive, action: {
                            showClearConfirmation = true
                        }) {
                            Text("Clear")
                                .foregroundColor(.red)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear History", isPresented: $showClearConfirmation) {
                Button("Clear All History", role: .destructive) {
                    viewModel.historyManager.clearAllHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all visited pages from your local history.")
            }
        }
    }
}

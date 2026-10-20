import SwiftUI

/// Address bar component supporting URL entry, search queries, HTTPS status, and quick reload
public struct AddressBarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @FocusState private var isFieldFocused: Bool

    public var body: some View {
        HStack(spacing: 8) {
            // Security or Search Icon
            if isFieldFocused {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
            } else if viewModel.activeTab.isHome {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
            } else if viewModel.activeTab.isSecure {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 13))
            } else {
                Image(systemName: "lock.slash.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            }

            // Text Input
            TextField("Search or enter website name", text: $viewModel.urlInputText)
                .keyboardType(.webSearch)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFieldFocused)
                .font(.system(size: 15, weight: .regular))
                .onSubmit {
                    viewModel.load(input: viewModel.urlInputText)
                    isFieldFocused = false
                }

            // Clear or Reload / Stop Action Button
            if isFieldFocused && !viewModel.urlInputText.isEmpty {
                Button(action: {
                    viewModel.urlInputText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                }
            } else if viewModel.activeTab.isLoading {
                Button(action: {
                    viewModel.stopLoading()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .font(.system(size: 14, weight: .bold))
                }
            } else if !viewModel.activeTab.isHome {
                Button(action: {
                    viewModel.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFieldFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
    }
}

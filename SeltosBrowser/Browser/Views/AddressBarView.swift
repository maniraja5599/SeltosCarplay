import SwiftUI

/// Address bar component supporting URL entry, search queries, native Voice Search, HTTPS status, and quick reload
public struct AddressBarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject private var voiceSearch = VoiceSearchManager.shared
    @FocusState private var isFieldFocused: Bool

    public var body: some View {
        HStack(spacing: 8) {
            // Security or Search Icon
            if isFieldFocused || viewModel.activeTab.isHome {
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
            TextField(
                voiceSearch.isListening ? "Listening... Speak now" : "Search or enter website name",
                text: $viewModel.urlInputText
            )
            .keyboardType(.webSearch)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .focused($isFieldFocused)
            .font(.system(size: 15, weight: .regular))
            .onSubmit {
                viewModel.load(input: viewModel.urlInputText)
                isFieldFocused = false
            }

            // Voice Search Microphone Button
            Button(action: {
                voiceSearch.toggleListening { transcribed in
                    viewModel.urlInputText = transcribed
                }
            }) {
                Image(systemName: voiceSearch.isListening ? "mic.fill" : "mic")
                    .foregroundColor(voiceSearch.isListening ? .red : .secondary)
                    .font(.system(size: 16, weight: voiceSearch.isListening ? .bold : .regular))
                    .scaleEffect(voiceSearch.isListening ? 1.15 : 1.0)
                    .animation(voiceSearch.isListening ? Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: voiceSearch.isListening)
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
                .stroke(voiceSearch.isListening ? Color.red : (isFieldFocused ? Color.accentColor : Color.clear), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
    }
}

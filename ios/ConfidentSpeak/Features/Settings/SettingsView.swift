import SwiftUI
import BYOKLLMKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $viewModel.provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: viewModel.provider) { _, _ in viewModel.providerChanged() }

                    SecureField("API key", text: $viewModel.apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    if viewModel.hasStoredKey {
                        Label("Key is configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Button("Save Key") { viewModel.saveKey() }
                            .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                        if viewModel.hasStoredKey {
                            Button("Remove", role: .destructive) { viewModel.clearKey() }
                        }
                    }
                } header: {
                    Text("Coach Feedback")
                } footer: {
                    Text("Get a key from \(viewModel.provider.keyHint). Without a key, drills still record, transcribe, and score locally — only the coach-feedback step is skipped.")
                }

                Section("Model") {
                    TextField(viewModel.provider.exampleModelID, text: $viewModel.model)
                        .autocorrectionDisabled()
                        .onSubmit { viewModel.saveModel() }
                }

                if let status = viewModel.statusMessage {
                    Section {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}

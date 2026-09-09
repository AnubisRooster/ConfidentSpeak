import SwiftUI
import BYOKLLMKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Use on-device model",
                        isOn: Binding(
                            get: { viewModel.isLocal },
                            set: { viewModel.toggleLocal($0) }
                        )
                    )
                } header: {
                    Text("On-Device")
                } footer: {
                    if viewModel.isLocal {
                        Text("100% local — recording, transcription, scoring, and coach feedback all run on this iPhone. No internet or API key required.")
                    } else {
                        Text("Runs the coach-feedback step entirely on this device with a downloaded model or Apple Intelligence.")
                    }
                }

                if viewModel.isLocal {
                    localModelSections
                } else {
                    cloudSections
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
            .onAppear { viewModel.reloadFromStorage() }
        }
    }

    // MARK: - Cloud (existing)

    @ViewBuilder
    private var cloudSections: some View {
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

        Section {
            if viewModel.provider == .openrouter {
                NavigationLink {
                    OpenRouterModelPickerView()
                } label: {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(viewModel.model)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            TextField(viewModel.provider.exampleModelID, text: $viewModel.model)
                .autocorrectionDisabled()
                .onSubmit { viewModel.saveModel() }
        } header: {
            Text("Model")
        } footer: {
            if viewModel.provider == .openrouter {
                Text("Tap to pick from free OpenRouter models (text + speech first). Or type any model ID directly.")
            }
        }
    }

    // MARK: - On-device

    @ViewBuilder
    private var localModelSections: some View {
        let installed = viewModel.localModels.filter { viewModel.isInstalled($0.id) }

        if installed.isEmpty {
            Section {
                Text("No model installed yet. Download one below to enable on-device coach feedback.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Local Model")
            }
        } else {
            Section {
                Picker("Model", selection: Binding(
                    get: {
                        if let selected = viewModel.selectedLocalModelID,
                           installed.contains(where: { $0.id == selected }) {
                            return selected
                        }
                        return installed.first?.id ?? ""
                    },
                    set: { viewModel.selectLocalModel($0) }
                )) {
                    ForEach(installed) { model in
                        Text(model.name).tag(model.id)
                    }
                }
            } header: {
                Text("Local Model")
            } footer: {
                if let model = viewModel.selectedLocalModelID.flatMap({ id in
                    viewModel.localModels.first(where: { $0.id == id })
                }) {
                    Text("Using \(model.name). \(model.description)")
                }
            }
        }

        Section("Available Models") {
            ForEach(viewModel.localModels) { model in
                localModelRow(model)
            }
        }
    }

    @ViewBuilder
    private func localModelRow(_ model: LocalModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .fontWeight(.medium)
                    if model.kind == .appleFoundation {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text(model.sizeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if model.kind == .appleFoundation {
                    Text(viewModel.appleFoundationStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if viewModel.isDownloading(model.id) {
                    ProgressView(value: viewModel.progress(for: model.id))
                        .progressViewStyle(.linear)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if model.kind == .appleFoundation {
                if viewModel.isInstalled(model.id) {
                    Text("Built-in")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isDownloading(model.id) {
                Button("Cancel") { viewModel.cancelDownload(model.id) }
                    .font(.caption)
            } else if viewModel.isInstalled(model.id) {
                Button("Delete", role: .destructive) { viewModel.deleteModel(model.id) }
                    .font(.caption)
            } else {
                Button {
                    viewModel.startDownload(model)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
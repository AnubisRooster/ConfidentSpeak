import SwiftUI

/// Promotes OpenRouter's model catalogue for selection — free models first,
/// text+speech-capable models at the top of the free list — plus search,
/// manual refresh, and a free-text fallback for IDs that aren't in the list.
struct OpenRouterModelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = OpenRouterModelService()

    @State private var query = ""
    @State private var customID: String = FeedbackSettings.model

    var body: some View {
        Group {
            if service.isLoading && service.models.isEmpty {
                ProgressView("Fetching models…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        TextField("Custom model ID (optional)", text: $customID)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .onSubmit { select(id: customID) }
                    } footer: {
                        Text("Pick from the catalogue below, or type an exact OpenRouter model ID for one that isn't listed.")
                            .font(.caption)
                    }

                    let free = filter(service.freeModels)
                    if !free.isEmpty {
                        Section {
                            ForEach(free) { model in
                                modelRow(model)
                            }
                        } header: {
                            Label("Free Models", systemImage: "gift")
                        } footer: {
                            Text("Free models are prioritised — text + speech models appear first.")
                                .font(.caption)
                        }
                    }

                    let paid = filter(service.paidModels)
                    if !paid.isEmpty {
                        Section("Paid Models") {
                            ForEach(paid) { model in
                                modelRow(model)
                            }
                        }
                    }

                    if service.models.isEmpty {
                        ContentUnavailableView(
                            "No Models",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text(service.lastError
                                ?? "Couldn't load the OpenRouter catalogue. Check your connection and try refreshing.")
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search OpenRouter models"
                )
            }
        }
        .navigationTitle("Choose Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(service.isLoading)
                .accessibilityLabel("Refresh model list")
            }
        }
        .task { await service.refreshIfNeeded() }
    }

    // MARK: - Rows

    @ViewBuilder
    private func modelRow(_ model: OpenRouterModel) -> some View {
        let isSelected = FeedbackSettings.model == model.id

        Button {
            select(id: model.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(rowDetail(model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isFree {
                    CapabilityCapsule(label: "FREE", color: .green)
                }
                if model.isTextAndSpeech {
                    CapabilityCapsule(label: "TEXT + SPEECH", color: .teal)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func select(id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        FeedbackSettings.model = trimmed
        dismiss()
    }

    private func filter(_ list: [OpenRouterModel]) -> [OpenRouterModel] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) }
    }

    private func rowDetail(_ model: OpenRouterModel) -> String {
        let capabilities = model.isTextAndSpeech ? "Text + Speech \u{00B7} " : ""
        return capabilities + contextLabel(model.contextLength) + (model.isFree ? "" : " \u{00B7} \(model.shortName)")
    }

    private func contextLabel(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return "\(tokens / 1_000_000)M context" }
        if tokens >= 1_000 { return "\(tokens / 1_000)K context" }
        return "\(tokens) tokens"
    }
}

/// Small rounded tag used for FREE / TEXT + SPEECH badges.
private struct CapabilityCapsule: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(day: ProgramDay, database: AppDatabase, onSaved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RecordingViewModel(day: day, database: database))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.day.drillInstructions)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if viewModel.day.requiresRecording {
                    recordingSection
                } else {
                    reflectionOnlySection
                }

                if let transcript = viewModel.transcript {
                    resultsSection(transcript: transcript)
                }

                if case .failed(let message) = viewModel.stage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Day \(viewModel.day.id)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.stage) { _, newStage in
            if case .saved = newStage {
                onSaved()
            }
        }
    }

    private var recordingSection: some View {
        VStack(spacing: 16) {
            Button(action: toggleRecording) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(viewModel.isRecording ? .red : .accentColor)
            }
            .disabled(viewModel.isBusy && !viewModel.isRecording)

            statusLabel
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch viewModel.stage {
        case .idle:
            Text("Tap to start recording")
                .foregroundStyle(.secondary)
        case .recording:
            Text(String(format: "Recording… %.0fs", viewModel.currentDuration))
        case .transcribing:
            ProgressView("Transcribing on-device…")
        case .gettingFeedback:
            ProgressView("Getting feedback…")
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            EmptyView()
        }
    }

    private func toggleRecording() {
        Task {
            if viewModel.isRecording {
                await viewModel.stopRecordingAndAnalyze()
            } else {
                await viewModel.startRecording()
            }
        }
    }

    private func resultsSection(transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript").font(.headline)
            Text(transcript).font(.callout)

            if let metrics = viewModel.metrics {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metrics").font(.headline)
                    Text("\(Int(metrics.wordsPerMinute)) words per minute")
                    Text("\(metrics.fillerWordCount) filler word(s)")
                    Text("\(metrics.pauseCount) pause(s) over 0.5s")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let feedback = viewModel.llmFeedback {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach feedback").font(.headline)
                    Text(feedback)
                }
                .font(.callout)
            }

            reflectionField
        }
    }

    private var reflectionOnlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            reflectionField
            Button("Save Reflection") {
                Task { await viewModel.saveReflectionOnly() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.reflectionNote.isEmpty || viewModel.isBusy)
        }
    }

    private var reflectionField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reflection (optional)").font(.headline)
            TextEditor(text: $viewModel.reflectionNote)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }
}

#Preview {
    NavigationStack {
        RecordingView(
            day: ProgramContent.days[0],
            database: .preview(),
            onSaved: {}
        )
    }
}

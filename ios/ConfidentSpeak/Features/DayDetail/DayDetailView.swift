import SwiftUI

struct DayDetailView: View {
    @StateObject private var viewModel: DayDetailViewModel
    let database: AppDatabase

    init(day: ProgramDay, database: AppDatabase) {
        self.database = database
        _viewModel = StateObject(wrappedValue: DayDetailViewModel(day: day, database: database))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.day.summary)
                    .font(.body)

                if let session = viewModel.latestSession {
                    lastAttemptSection(session)
                }

                NavigationLink {
                    RecordingView(day: viewModel.day, database: database) {
                        Task { await viewModel.refresh() }
                    }
                } label: {
                    Label(
                        viewModel.day.requiresRecording ? "Start Drill" : "Reflect",
                        systemImage: viewModel.day.requiresRecording ? "mic.fill" : "text.bubble.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Day \(viewModel.day.id)")
        .task { await viewModel.refresh() }
    }

    private func lastAttemptSection(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Last attempt").font(.headline)

            if let wpm = session.wordsPerMinute {
                Text("\(Int(wpm)) words per minute, \(session.fillerWordCount ?? 0) filler word(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let feedback = session.llmFeedback {
                Text(feedback).font(.callout)
            }
            if let note = session.reflectionNote, !note.isEmpty {
                Text(note).font(.callout).italic()
            }
        }
    }
}

#Preview {
    NavigationStack {
        DayDetailView(day: ProgramContent.days[0], database: .preview())
    }
}

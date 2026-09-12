import SwiftUI
import Foundation
import Charts

struct ProgramProgressView: View {
    @StateObject private var viewModel: ProgramProgressViewModel

    init(database: AppDatabase) {
        _viewModel = StateObject(wrappedValue: ProgramProgressViewModel(database: database))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(viewModel.completedDayCount) of 14 days completed")
                        .font(.headline)
                    ProgressView(value: viewModel.progressFraction)
                }
                .padding(.vertical, 4)
            }

            if viewModel.averageWordsPerMinute != nil || viewModel.averageFillerWordCount != nil {
                Section("Averages") {
                    if let wpm = viewModel.averageWordsPerMinute {
                        LabeledContent("Words per minute", value: String(format: "%.0f", wpm))
                    }
                    if let filler = viewModel.averageFillerWordCount {
                        LabeledContent("Filler words per clip", value: String(format: "%.1f", filler))
                    }
                    if let score = viewModel.averageQualityScore {
                        LabeledContent("Average quality", value: String(format: "%.1f/10", score))
                    }
                }
            }

            if !viewModel.scoredOverTime.isEmpty {
                Section("Score over time") {
                    ScoreChart(points: viewModel.scoredOverTime, average: viewModel.averageQualityScore)
                    .frame(height: 220)
                    .padding(.vertical, 4)
                }
            }

            if !viewModel.scoredSessions.isEmpty {
                Section("Quality trend") {
                    ForEach(viewModel.scoredSessions, id: \.session.id) { item in
                        ScoreTrendRow(session: item.session, score: item.score)
                    }
                }
            }

            Section("History") {
                if viewModel.completedSessions.isEmpty {
                    Text("No completed drills yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.completedSessions) { session in
                        HistoryRow(session: session)
                    }
                }
            }
        }
        .navigationTitle("Progress")
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private func qualityColor(_ score: Int) -> Color {
    score >= 7 ? .green : score >= 4 ? .orange : .red
}

private struct ScoreChart: View {
    let points: [ScorePoint]
    let average: Double?

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(qualityColor(point.score))
            }

            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.orange.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(Int(average.rounded()))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
        }
        .chartYScale(domain: 0...10)
    }
}

private struct ScoreTrendRow: View {
    let session: PracticeSession
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rowTitle)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text("\(score)/10")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(qualityColor(score))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(qualityColor(score))
                        .frame(width: max(4, geo.size.width * Double(score) / 10))
                }
            }
            .frame(height: 8)
        }
    }

    private var rowTitle: String {
        var title = ProgramContent.days.first(where: { $0.id == session.day })?.title ?? "Day \(session.day)"
        if let date = session.completedAt {
            title += " · " + date.formatted(date: .abbreviated, time: .omitted)
        }
        return title
    }
}

private struct HistoryRow: View {
    let session: PracticeSession

    private var dayTitle: String {
        ProgramContent.days.first(where: { $0.id == session.day })?.title ?? "Day \(session.day)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Day \(session.day): \(dayTitle)").font(.subheadline)
            if let wpm = session.wordsPerMinute {
                Text("\(Int(wpm)) wpm · \(session.fillerWordCount ?? 0) filler words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let note = session.reflectionNote, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProgramProgressView(database: .preview())
    }
}

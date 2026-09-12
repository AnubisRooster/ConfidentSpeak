import Foundation

/// One plotted score in the Progress time-series chart.
struct ScorePoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let score: Int
}

@MainActor
final class ProgramProgressViewModel: ObservableObject {
    @Published private(set) var completedSessions: [PracticeSession] = []
    @Published private(set) var isLoading = false

    private let database: AppDatabase
    private let totalDays = ProgramContent.days.count

    init(database: AppDatabase) {
        self.database = database
    }

    var completedDayCount: Int {
        Set(completedSessions.map(\.day)).count
    }

    var progressFraction: Double {
        totalDays == 0 ? 0 : Double(completedDayCount) / Double(totalDays)
    }

    var averageWordsPerMinute: Double? {
        let values = completedSessions.compactMap(\.wordsPerMinute)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var averageFillerWordCount: Double? {
        let values = completedSessions.compactMap(\.fillerWordCount)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Sessions with a parsed LLM quality score, in program-day order, so the
    /// Progress tab can show how performance trends across the 14 days.
    var scoredSessions: [(session: PracticeSession, score: Int)] {
        completedSessions.compactMap { session in
            session.displayedScore.map { (session, $0) }
        }
    }

    /// Average of the parsed quality scores; `nil` when nothing is scored yet.
    var averageQualityScore: Double? {
        let values = scoredSessions.map(\.score)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Same scored sessions as `scoredSessions`, but ordered by when the drill
    /// actually happened (all attempts, multiple per day allowed) so the chart
    /// reads as a true time series rather than a day-indexed list.
    var scoredOverTime: [ScorePoint] {
        scoredSessions
            .map { ScorePoint(date: $0.session.completedAt ?? $0.session.createdAt, score: $0.score) }
            .sorted { $0.date < $1.date }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        completedSessions = (try? await database.completedSessions()) ?? []
    }
}

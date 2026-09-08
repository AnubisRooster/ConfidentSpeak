import Foundation

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

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        completedSessions = (try? await database.completedSessions()) ?? []
    }
}

import Foundation

@MainActor
final class DayDetailViewModel: ObservableObject {
    @Published private(set) var latestSession: PracticeSession?
    @Published private(set) var isLoading = false

    let day: ProgramDay
    private let database: AppDatabase

    init(day: ProgramDay, database: AppDatabase) {
        self.day = day
        self.database = database
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let dayId = day.id
        latestSession = try? await database.dbWriter.read { db in
            try PracticeSession.latest(forDay: dayId, db: db)
        }
    }
}

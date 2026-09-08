import Foundation

@MainActor
final class DayListViewModel: ObservableObject {
    @Published private(set) var latestSessionByDay: [Int: PracticeSession] = [:]
    @Published private(set) var isLoading = false

    let days = ProgramContent.days
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func isCompleted(_ day: ProgramDay) -> Bool {
        latestSessionByDay[day.id]?.completedAt != nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        latestSessionByDay = (try? await database.latestSessionsByDay()) ?? [:]
    }
}

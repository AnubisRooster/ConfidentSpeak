import Testing
import Foundation
import GRDB
@testable import ConfidentSpeak

struct AppDatabaseTests {
    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    @Test func savingASessionAssignsAnId() async throws {
        let database = try makeDatabase()
        let session = PracticeSession(day: 1, lessonKey: "first_impressions")
        let saved = try await database.save(session)
        #expect(saved.id != nil)
    }

    @Test func latestSessionForDayReturnsMostRecentAttempt() async throws {
        let database = try makeDatabase()
        let older = PracticeSession(day: 2, lessonKey: "voice_pace", createdAt: Date(timeIntervalSince1970: 0))
        let newer = PracticeSession(day: 2, lessonKey: "voice_pace", createdAt: Date(timeIntervalSince1970: 1000))
        _ = try await database.save(older)
        let savedNewer = try await database.save(newer)

        let latestByDay = try await database.latestSessionsByDay()
        #expect(latestByDay[2]?.id == savedNewer.id)
    }

    @Test func completedSessionsExcludesInProgressAttempts() async throws {
        let database = try makeDatabase()
        let incomplete = PracticeSession(day: 3, lessonKey: "confidence_wins")
        let complete = PracticeSession(day: 3, lessonKey: "confidence_wins", completedAt: Date())
        _ = try await database.save(incomplete)
        _ = try await database.save(complete)

        let completed = try await database.completedSessions()
        #expect(completed.count == 1)
        #expect(completed.first?.completedAt != nil)
    }

    @Test func daysWithNoAttemptsAreAbsentFromLatestByDay() async throws {
        let database = try makeDatabase()
        let latestByDay = try await database.latestSessionsByDay()
        #expect(latestByDay.isEmpty)
    }
}

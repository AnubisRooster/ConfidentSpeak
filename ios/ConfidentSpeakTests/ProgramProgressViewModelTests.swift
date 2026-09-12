import Testing
import Foundation
import GRDB
@testable import ConfidentSpeak

@MainActor
struct ProgramProgressViewModelTests {
    private func makeViewModel(sessions: [PracticeSession]) async throws -> ProgramProgressViewModel {
        let database = try AppDatabase(DatabaseQueue())
        for session in sessions {
            _ = try await database.save(session)
        }
        let viewModel = ProgramProgressViewModel(database: database)
        await viewModel.refresh()
        return viewModel
    }

    @Test func qualityAverageAndScoredSessionsUseDisplayedScore() async throws {
        let viewModel = try await makeViewModel(sessions: [
            PracticeSession(day: 1, lessonKey: "first", llmFeedback: "Score: 8/10", qualityScore: 8, completedAt: Date()),
            PracticeSession(day: 2, lessonKey: "second", llmFeedback: "Score: 6/10", qualityScore: 6, completedAt: Date()),
            PracticeSession(day: 3, lessonKey: "unscored"),
        ])

        #expect(viewModel.scoredSessions.count == 2)
        #expect(viewModel.scoredSessions.map(\.score) == [8, 6])
        #expect(viewModel.averageQualityScore == 7.0)
    }

    @Test func unscoredSessionsDoNotAffectAverages() async throws {
        let viewModel = try await makeViewModel(sessions: [
            PracticeSession(day: 1, lessonKey: "quiet", qualityScore: nil, completedAt: Date()),
        ])
        #expect(viewModel.scoredSessions.isEmpty)
        #expect(viewModel.averageQualityScore == nil)
    }
}
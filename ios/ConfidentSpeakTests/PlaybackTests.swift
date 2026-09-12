import Testing
import Foundation
@testable import ConfidentSpeak

struct PlaybackTests {
    @Test func recordingStorePersistsAndResolvesAClip() throws {
        let store = RecordingStore.shared
        let tempDir = FileManager.default.temporaryDirectory
        let source = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data("dummy-audio".utf8).write(to: source)

        let relativePath = store.persistRecording(from: source)
        #expect(relativePath != nil)
        #expect(relativePath == source.lastPathComponent)
        #expect(store.url(forRelativePath: relativePath) != nil)
        #expect(FileManager.default.fileExists(atPath: source.path) == false)
        #expect(store.url(forRelativePath: nil) == nil)
        #expect(store.url(forRelativePath: "missing.m4a") == nil)

        if let url = store.url(forRelativePath: relativePath) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

struct FeedbackScoringTests {
    @Test func parseScoreHandlesStructuredOutput() {
        #expect(FeedbackEngine.parseScore(from: "Score: 8/10\nStrengths: ...") == 8)
        #expect(FeedbackEngine.parseScore(from: "\nScore: 4 / 10\n\nImprovement: ...") == 4)
    }

    @Test func parseScoreFallsBackToBareRatings() {
        #expect(FeedbackEngine.parseScore(from: "7/10 overall, keep it up") == 7)
        #expect(FeedbackEngine.parseScore(from: "Score: 10/10") == 10)
    }

    @Test func parseScoreReturnsNilWhenAbsentOrGarbage() {
        #expect(FeedbackEngine.parseScore(from: "Nice pacing, fewer fillers next time") == nil)
        #expect(FeedbackEngine.parseScore(from: "Score: X/10") == nil)
        #expect(FeedbackEngine.parseScore(from: "99/100") == nil)
    }

    @Test func parseScoreClampsOutOfRange() {
        #expect(FeedbackEngine.parseScore(from: "Score: 12/10") == 10)
        #expect(FeedbackEngine.parseScore(from: "Score: 0/10") == 1)
    }
}
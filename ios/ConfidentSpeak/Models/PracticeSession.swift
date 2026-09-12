import Foundation
import GRDB

/// One user attempt at a day's drill. Mirrors the LLM performance-track
/// schema pattern from OnDeviceKit (CompyPal), repurposed for speaking metrics.
struct PracticeSession: Codable, Equatable, FetchableRecord, MutablePersistableRecord, Identifiable {
    static let databaseTableName = "practice_session"

    var id: Int64?
    var day: Int                    // 1...14, matches ProgramDay.id
    var lessonKey: String
    var transcript: String?
    var wordsPerMinute: Double?
    var fillerWordCount: Int?
    var pauseCount: Int?
    var llmFeedback: String?
    var reflectionNote: String?
    var recordingDurationSeconds: Double?
    var recordingPath: String?
    var completedAt: Date?
    var createdAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(
        id: Int64? = nil,
        day: Int,
        lessonKey: String,
        transcript: String? = nil,
        wordsPerMinute: Double? = nil,
        fillerWordCount: Int? = nil,
        pauseCount: Int? = nil,
        llmFeedback: String? = nil,
        reflectionNote: String? = nil,
        recordingDurationSeconds: Double? = nil,
        recordingPath: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.day = day
        self.lessonKey = lessonKey
        self.transcript = transcript
        self.wordsPerMinute = wordsPerMinute
        self.fillerWordCount = fillerWordCount
        self.pauseCount = pauseCount
        self.llmFeedback = llmFeedback
        self.reflectionNote = reflectionNote
        self.recordingDurationSeconds = recordingDurationSeconds
        self.recordingPath = recordingPath
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}

// MARK: - Convenience queries

extension PracticeSession {
    static func latest(forDay day: Int, db: Database) throws -> PracticeSession? {
        try PracticeSession
            .filter(Column("day") == day)
            .order(Column("createdAt").desc)
            .fetchOne(db)
    }

    static func allCompleted(db: Database) throws -> [PracticeSession] {
        try PracticeSession
            .filter(Column("completedAt") != nil)
            .order(Column("day").asc)
            .fetchAll(db)
    }
}

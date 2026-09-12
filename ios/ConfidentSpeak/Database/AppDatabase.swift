import Foundation
import GRDB

/// Central database access point. Migration pattern mirrors the
/// DatabaseMigrator approach from CompyPal/OnDeviceKit — named,
/// ordered migrations, one table's foreign-key dependencies always
/// created before the table that references them (this was the root
/// cause of the CompyPal fresh-install bug — don't repeat it here).
final class AppDatabase {
    let dbWriter: DatabaseWriter

    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_createPracticeSession") { db in
            try db.create(table: "practice_session") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("day", .integer).notNull()
                t.column("lessonKey", .text).notNull()
                t.column("transcript", .text)
                t.column("wordsPerMinute", .double)
                t.column("fillerWordCount", .integer)
                t.column("pauseCount", .integer)
                t.column("llmFeedback", .text)
                t.column("reflectionNote", .text)
                t.column("recordingDurationSeconds", .double)
                t.column("completedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_practice_session_day", on: "practice_session", columns: ["day"])
        }

        migrator.registerMigration("v2_addRecordingPath") { db in
            try db.alter(table: "practice_session") { t in
                t.add(column: "recordingPath", .text)
            }
        }

        return migrator
    }

    /// Standard on-disk database in Application Support, matching
    /// CompyPal/therAIpist's storage location convention.
    static func makeShared() throws -> AppDatabase {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("ConfidentSpeak", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let dbURL = directoryURL.appendingPathComponent("db.sqlite")
        let dbPool = try DatabasePool(path: dbURL.path)
        return try AppDatabase(dbPool)
    }
}

// MARK: - Convenience async API for view models

extension AppDatabase {
    /// The most recently created `PracticeSession` for each day that has at
    /// least one attempt, keyed by day number.
    func latestSessionsByDay() async throws -> [Int: PracticeSession] {
        try await dbWriter.read { db in
            var result: [Int: PracticeSession] = [:]
            for programDay in ProgramContent.days {
                if let session = try PracticeSession.latest(forDay: programDay.id, db: db) {
                    result[programDay.id] = session
                }
            }
            return result
        }
    }

    /// All sessions that were carried through to completion, oldest day first.
    func completedSessions() async throws -> [PracticeSession] {
        try await dbWriter.read { db in
            try PracticeSession.allCompleted(db: db)
        }
    }

    /// Inserts or updates `session`, returning the persisted copy (with its
    /// assigned `id` on first insert).
    @discardableResult
    func save(_ session: PracticeSession) async throws -> PracticeSession {
        try await dbWriter.write { db in
            var mutableSession = session
            try mutableSession.save(db)
            return mutableSession
        }
    }
}

#if DEBUG
extension AppDatabase {
    /// In-memory database for SwiftUI previews and quick manual testing.
    static func preview() -> AppDatabase {
        try! AppDatabase(DatabaseQueue())
    }
}
#endif

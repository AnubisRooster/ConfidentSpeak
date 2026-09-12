import Foundation

/// Persists recorded practice clips in `Documents/recordings/` and lets view
/// models resolve them back. `PracticeSession.recordingPath` stores the
/// *relative* filename — portable across app-container moves/reinstalls.
struct RecordingStore {
    static let shared = RecordingStore()

    /// Moves `source` (a temporary recording) into the app's recordings
    /// directory, returning the relative filename to persist on the session,
    /// or `nil` if the move failed.
    func persistRecording(from source: URL) -> String? {
        let fm = FileManager.default
        try? fm.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)

        let relativePath = source.lastPathComponent
        let destination = recordingsDirectory.appendingPathComponent(relativePath)

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: source, to: destination)
            return relativePath
        } catch {
            return nil
        }
    }

    /// Resolves a relative `recordingPath` to an existing file URL, or `nil`
    /// when the path is missing or the file is gone.
    func url(forRelativePath relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        let url = recordingsDirectory.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings", isDirectory: true)
    }
}
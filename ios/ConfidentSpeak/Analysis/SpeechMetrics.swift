import Foundation

/// Computes objective speaking metrics from a transcript + timing data.
/// Deliberately no LLM call here — these are deterministic calculations;
/// the LLM (FeedbackEngine) only interprets the results afterward.
struct SpeechMetrics {
    let wordsPerMinute: Double
    let fillerWordCount: Int
    let pauseCount: Int
    let longestPauseSeconds: TimeInterval

    private static let fillerWordPattern = try! NSRegularExpression(
        pattern: #"\b(um+|uh+|like|you know|sort of|kind of|basically|actually)\b"#,
        options: .caseInsensitive
    )

    /// A gap between consecutive segments longer than this counts as a pause.
    private static let pauseThresholdSeconds: TimeInterval = 0.5

    static func compute(
        transcript: String,
        segments: [(text: String, start: TimeInterval, duration: TimeInterval)],
        totalDurationSeconds: TimeInterval
    ) -> SpeechMetrics {
        let wordCount = transcript
            .split(whereSeparator: { $0.isWhitespace })
            .filter { !$0.isEmpty }
            .count

        let minutes = max(totalDurationSeconds / 60.0, 0.01) // avoid divide-by-zero on very short clips
        let wpm = Double(wordCount) / minutes

        let fillerCount = fillerWordPattern.numberOfMatches(
            in: transcript,
            range: NSRange(transcript.startIndex..., in: transcript)
        )

        var pauses: [TimeInterval] = []
        for i in 1..<max(segments.count, 1) where i < segments.count {
            let previousEnd = segments[i - 1].start + segments[i - 1].duration
            let gap = segments[i].start - previousEnd
            if gap >= pauseThresholdSeconds {
                pauses.append(gap)
            }
        }

        return SpeechMetrics(
            wordsPerMinute: wpm.rounded(),
            fillerWordCount: fillerCount,
            pauseCount: pauses.count,
            longestPauseSeconds: pauses.max() ?? 0
        )
    }
}

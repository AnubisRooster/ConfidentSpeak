import Testing
@testable import ConfidentSpeak

struct SpeechMetricsTests {
    @Test func wordsPerMinuteScalesWithDuration() {
        let metrics = SpeechMetrics.compute(
            transcript: "one two three four five six seven eight nine ten",
            segments: [],
            totalDurationSeconds: 30
        )
        // 10 words in 30s == 0.5 minutes -> 20 wpm
        #expect(metrics.wordsPerMinute == 20)
    }

    @Test func veryShortClipDoesNotDivideByZero() {
        let metrics = SpeechMetrics.compute(
            transcript: "hi",
            segments: [],
            totalDurationSeconds: 0
        )
        #expect(metrics.wordsPerMinute.isFinite)
        #expect(metrics.wordsPerMinute > 0)
    }

    @Test func countsCaseInsensitiveFillerWords() {
        let metrics = SpeechMetrics.compute(
            transcript: "Um, so like, you know, basically it went fine, actually.",
            segments: [],
            totalDurationSeconds: 60
        )
        #expect(metrics.fillerWordCount == 5)
    }

    @Test func detectsPausesAboveThreshold() {
        let segments: [(text: String, start: TimeInterval, duration: TimeInterval)] = [
            (text: "hello", start: 0, duration: 1),
            // gap of 0.6s clears the 0.5s threshold
            (text: "world", start: 1.6, duration: 1),
            // gap of 0.2s does not
            (text: "there", start: 2.8, duration: 1),
        ]
        let metrics = SpeechMetrics.compute(
            transcript: "hello world there",
            segments: segments,
            totalDurationSeconds: 4
        )
        #expect(metrics.pauseCount == 1)
        #expect(abs(metrics.longestPauseSeconds - 0.6) < 0.0001)
    }

    @Test func noGapsMeansNoPauses() {
        let metrics = SpeechMetrics.compute(transcript: "hello", segments: [], totalDurationSeconds: 5)
        #expect(metrics.pauseCount == 0)
        #expect(metrics.longestPauseSeconds == 0)
    }
}

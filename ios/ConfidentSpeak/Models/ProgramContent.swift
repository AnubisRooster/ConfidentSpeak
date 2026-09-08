import Foundation

/// A single day's lesson + practice drill in the 14-day program.
struct ProgramDay: Identifiable, Codable, Hashable {
    let id: Int                 // day number, 1...14
    let title: String
    let lessonKey: String       // stable key used in PracticeSession.lessonKey
    let summary: String         // short lesson text shown on DayDetailView
    let drillInstructions: String
    let requiresRecording: Bool // false for pure-reflection days
}

enum ProgramContent {
    /// Static 14-day roadmap. No database needed — this is bundled content,
    /// not user data. User progress against these days lives in PracticeSession.
    static let days: [ProgramDay] = [
        ProgramDay(
            id: 1,
            title: "First Impressions",
            lessonKey: "first_impressions",
            summary: "Strong entrances set the tone before you say a word: shoulders back, 2-second eye contact, firm handshake or nod.",
            drillInstructions: "Record yourself saying \"Hi, I'm [name]\" five times until it sounds natural, not performed.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 2,
            title: "Voice & Pace",
            lessonKey: "voice_pace",
            summary: "Most people speed up and mumble when nervous. Slowing down reads as confidence, not hesitation.",
            drillInstructions: "Read a paragraph aloud at your normal pace, then again 20% slower and 20% louder.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 3,
            title: "Confidence Wins",
            lessonKey: "confidence_wins",
            summary: "Confidence is built from small, repeated wins — not a personality trait you either have or don't.",
            drillInstructions: "Describe one recent moment you handled well, out loud, in under 60 seconds.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 4,
            title: "Speak Up in Any Room",
            lessonKey: "speak_up",
            summary: "The first thing said in a meeting sets the bar for how much room you're allowed to take up.",
            drillInstructions: "Commit to saying one thing in the first 5 minutes of your next meeting. Log what you said.",
            requiresRecording: false
        ),
        ProgramDay(
            id: 5,
            title: "Storytelling Secrets",
            lessonKey: "storytelling",
            summary: "A story needs structure: setup, tension, resolution, takeaway — not just a sequence of events.",
            drillInstructions: "Take one work anecdote and tell it aloud using that four-part structure.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 6,
            title: "Body Language",
            lessonKey: "body_language",
            summary: "Open posture — uncrossed arms, feet planted, visible hands — signals confidence before you speak.",
            drillInstructions: "Record a 30-second video of yourself talking about your day. Review posture only, ignore content.",
            requiresRecording: false
        ),
        ProgramDay(
            id: 7,
            title: "Read People Like a Pro",
            lessonKey: "read_people",
            summary: "Reading a room means watching for disengagement cues early enough to adjust before you lose them.",
            drillInstructions: "In your next conversation, note one moment you noticed the other person's energy shift.",
            requiresRecording: false
        ),
        ProgramDay(
            id: 8,
            title: "Give Tough Feedback Fast",
            lessonKey: "tough_feedback",
            summary: "Observation, impact, request — in that order — keeps feedback clear without it becoming a confrontation.",
            drillInstructions: "Practice saying: \"When X happened, it caused Y. Could we try Z?\" out loud.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 9,
            title: "Handle Difficult People Smartly",
            lessonKey: "difficult_people",
            summary: "Calm, short responses de-escalate faster than matching someone's energy.",
            drillInstructions: "Practice a calm one-line response to a hypothetical rude comment. Say it three ways.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 10,
            title: "Say No and Be Likable",
            lessonKey: "say_no",
            summary: "\"I can't take that on right now, but here's what I can do\" declines without over-explaining.",
            drillInstructions: "Practice that line out loud until it doesn't feel like you owe an apology.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 11,
            title: "Interrupt Smoothly",
            lessonKey: "interrupt_smoothly",
            summary: "A brief, polite interruption is more respected than staying silent and never getting your point in.",
            drillInstructions: "Practice: \"Can I jump in for a second?\" followed immediately by your point, no hedging.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 12,
            title: "Defuse Any Conflict",
            lessonKey: "defuse_conflict",
            summary: "Naming the tension out loud, calmly, often does more to defuse it than arguing the substance.",
            drillInstructions: "Practice: \"I think we're seeing this differently — can we back up?\" out loud.",
            requiresRecording: true
        ),
        ProgramDay(
            id: 13,
            title: "Listen Like a Leader",
            lessonKey: "listen_leader",
            summary: "Leaders listen for what's not being said as much as what is.",
            drillInstructions: "In one conversation today, ask one follow-up question before responding with your own view.",
            requiresRecording: false
        ),
        ProgramDay(
            id: 14,
            title: "The Power of a Perfect Pause",
            lessonKey: "perfect_pause",
            summary: "Ending a sentence and pausing before continuing reads as control, not uncertainty.",
            drillInstructions: "Record yourself speaking for 60 seconds, counting \"one-Mississippi\" after each sentence before continuing.",
            requiresRecording: true
        )
    ]
}

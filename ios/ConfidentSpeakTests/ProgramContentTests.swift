import Testing
@testable import ConfidentSpeak

struct ProgramContentTests {
    @Test func has14Days() {
        #expect(ProgramContent.days.count == 14)
    }

    @Test func dayIdsAreSequentialStartingAtOne() {
        let ids = ProgramContent.days.map(\.id)
        #expect(ids == Array(1...14))
    }

    @Test func lessonKeysAreUnique() {
        let keys = ProgramContent.days.map(\.lessonKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test func noDayHasEmptyContent() {
        for day in ProgramContent.days {
            #expect(!day.title.isEmpty)
            #expect(!day.summary.isEmpty)
            #expect(!day.drillInstructions.isEmpty)
        }
    }
}

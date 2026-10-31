import Testing
@testable import MacDuo

struct ManualEffectPlaybackTests {
    @Test func secondToggleCancelsPreparation() {
        var state = ManualEffectPlayback()
        let start = state.toggle(at: 0, duration: 2)
        #expect(start == .prepareClose && state.phase == .preparing)
        let cancel = state.toggle(at: 0.2, duration: 2)
        #expect(cancel == .cancelPreparation && state.phase == .idle)
    }
    @Test func holdsBlackThenRestoresAllTheWayToClear() {
        var state = ManualEffectPlayback()
        _ = state.toggle(at: 0, duration: 2)
        state.start(at: 10)
        let black = state.progress(at: 12, duration: 2)
        #expect(black == 1 && state.phase == .black)
        let held = state.progress(at: 1000, duration: 2)
        #expect(held == 1 && state.phase == .black)
        let restore = state.toggle(at: 1001, duration: 2)
        #expect(restore == .prepareRestore && state.phase == .preparingRestore)
        state.start(at: 1002)
        let half = state.progress(at: 1003, duration: 2)
        #expect(half == 0.5 && state.phase == .restoring)
        let clear = state.progress(at: 1004, duration: 2)
        #expect(clear == 0 && !state.isActive)
    }
    @Test func rapidReversalPreservesCurrentFrameInBothDirections() {
        var state = ManualEffectPlayback()
        _ = state.toggle(at: 0, duration: 2)
        state.start(at: 10)
        let reverse = state.toggle(at: 10.5, duration: 2)
        #expect(reverse == .directionChanged && state.phase == .restoring)
        let unchanged = state.progress(at: 10.5, duration: 2)
        #expect(unchanged == 0.25)
        let closing = state.toggle(at: 10.75, duration: 2)
        #expect(closing == .directionChanged && state.phase == .animating)
        let continuous = state.progress(at: 10.75, duration: 2)
        #expect(continuous == 0.125)
        let later = state.progress(at: 11, duration: 2)
        #expect(later == 0.25)
    }
    @Test func cancelledRestoreCannotStartFromLateCapture() {
        var state = ManualEffectPlayback()
        state.holdBlack()
        _ = state.toggle(at: 1, duration: 2)
        let cancelled = state.toggle(at: 1.1, duration: 2)
        #expect(cancelled == .cancelRestorePreparation && state.phase == .black)
        state.start(at: 2)
        #expect(state.phase == .black)
    }
}

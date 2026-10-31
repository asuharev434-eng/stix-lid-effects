import Testing
@testable import MacDuo

struct ManualEffectPlaybackTests {
    @Test func secondToggleCancelsPreparationAndAnimation() {
        var state = ManualEffectPlayback()
        let started = state.toggle()
        #expect(started && state.phase == .preparing)
        let preparingCancelled = state.toggle()
        #expect(!preparingCancelled && state.phase == .idle)
        _ = state.toggle()
        state.start(at: 10)
        let p = state.progress(at: 10.5, duration: 2)
        #expect(p == 0.25)
        let animationCancelled = state.toggle()
        #expect(!animationCancelled && state.phase == .idle)
    }
    @Test func staysBlackUntilNextToggle() {
        var state = ManualEffectPlayback()
        _ = state.toggle()
        state.start(at: 10)
        let completed = state.progress(at: 12, duration: 2)
        #expect(completed == 1 && state.phase == .black)
        let muchLater = state.progress(at: 1000, duration: 2)
        #expect(muchLater == 1 && state.phase == .black)
        let restored = state.toggle()
        #expect(!restored && !state.isActive)
    }
    @Test func holdingBlackDuringPreparationInvalidatesLaterStart() {
        var state = ManualEffectPlayback()
        _ = state.toggle()
        state.holdBlack()
        state.start(at: 20)
        #expect(state.phase == .black)
    }
}

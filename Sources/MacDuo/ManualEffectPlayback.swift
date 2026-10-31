import Foundation

enum ManualEffectPhase: Equatable {
    case idle, preparing, animating, black
}

/// A completed animation is a latched black screen, never a timed dismissal.
struct ManualEffectPlayback {
    private(set) var phase: ManualEffectPhase = .idle
    private var startedAt: TimeInterval = 0
    var isActive: Bool { phase != .idle }
    mutating func toggle() -> Bool {
        if isActive { cancel(); return false }
        phase = .preparing
        return true
    }
    mutating func start(at time: TimeInterval) {
        guard phase == .preparing else { return }
        startedAt = time
        phase = .animating
    }
    mutating func progress(at time: TimeInterval, duration: TimeInterval) -> Double {
        if phase == .black { return 1 }
        guard phase == .animating else { return 0 }
        let p = EffectStyle.progress((time - startedAt) / max(duration, 0.01))
        if p >= 1 { holdBlack() }
        return p
    }
    mutating func holdBlack() { phase = .black }
    mutating func cancel() { phase = .idle; startedAt = 0 }
}

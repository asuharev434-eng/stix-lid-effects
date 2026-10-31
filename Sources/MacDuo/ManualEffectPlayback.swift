import Foundation

enum ManualEffectPhase: Equatable {
    case idle, preparing, animating, black, preparingRestore, restoring
}

enum ManualEffectAction: Equatable {
    case prepareClose, cancelPreparation, prepareRestore, cancelRestorePreparation, directionChanged
}

/// One reversible progress coordinate: 0 is clear, 1 is latched black.
struct ManualEffectPlayback {
    private(set) var phase: ManualEffectPhase = .idle
    private var startedAt: TimeInterval = 0
    private var anchor: Double = 0
    var isActive: Bool { phase != .idle }

    mutating func toggle(at time: TimeInterval, duration: TimeInterval) -> ManualEffectAction {
        switch phase {
        case .idle:
            phase = .preparing
            return .prepareClose
        case .preparing:
            cancel()
            return .cancelPreparation
        case .black:
            phase = .preparingRestore
            return .prepareRestore
        case .preparingRestore:
            holdBlack()
            return .cancelRestorePreparation
        case .animating, .restoring:
            let wasClosing = phase == .animating
            anchor = progress(at: time, duration: duration)
            startedAt = time
            phase = wasClosing ? .restoring : .animating
            return .directionChanged
        }
    }
    mutating func start(at time: TimeInterval) {
        switch phase {
        case .preparing: phase = .animating; anchor = 0
        case .preparingRestore: phase = .restoring; anchor = 1
        default: return
        }
        startedAt = time
    }
    mutating func progress(at time: TimeInterval, duration: TimeInterval) -> Double {
        switch phase {
        case .black, .preparingRestore: return 1
        case .idle, .preparing: return 0
        case .animating, .restoring:
            let direction = phase == .animating ? 1.0 : -1.0
            let value = EffectStyle.progress(anchor + direction * max(0, time - startedAt) / max(duration, 0.01))
            if phase == .animating, value >= 1 { holdBlack() }
            else if phase == .restoring, value <= 0 { cancel() }
            return value
        }
    }
    mutating func holdBlack() { phase = .black; anchor = 1; startedAt = 0 }
    mutating func cancel() { phase = .idle; anchor = 0; startedAt = 0 }
}

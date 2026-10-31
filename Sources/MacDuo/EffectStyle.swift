import Foundation

enum EffectStyle: Int, CaseIterable, Identifiable {
    case original, television, frost, waves, paper, particles, edgeLight, cinema, shatter
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .original: return "Duo · Оригинал"
        case .television: return "Старый телевизор"
        case .frost: return "Матовое стекло"
        case .waves: return "Жидкая поверхность"
        case .paper: return "Лист бумаги"
        case .particles: return "Пыль и частицы"
        case .edgeLight: return "Свет по краям"
        case .cinema: return "Киношное открытие"
        case .shatter: return "Трещины и осколки"
        }
    }
    var symbol: String {
        switch self {
        case .original: return "laptopcomputer"
        case .television: return "tv"
        case .frost: return "snowflake"
        case .waves: return "water.waves"
        case .paper: return "doc"
        case .particles: return "sparkles"
        case .edgeLight: return "light.max"
        case .cinema: return "film"
        case .shatter: return "burst"
        }
    }
    static func progress(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }
}

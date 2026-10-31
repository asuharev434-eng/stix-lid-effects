import Foundation

enum EffectStyle: Int, CaseIterable, Identifiable {
    case original, television, frost, waves, paper, particles, edgeLight, cinema, shatter, cards, paintRoller, rubles, dollars
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
        case .cards: return "Колода карт"
        case .paintRoller: return "Малярный валик"
        case .rubles: return "Рубли · 5 000 ₽"
        case .dollars: return "Доллары · $100"
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
        case .cards: return "suit.spade.fill"
        case .paintRoller: return "paintbrush.pointed.fill"
        case .rubles: return "banknote.fill"
        case .dollars: return "dollarsign.circle.fill"
        }
    }
    var isFlyingPaper: Bool { self == .cards || banknoteCurrency != nil }
    var banknoteCurrency: BanknoteCurrency? {
        switch self {
        case .rubles: return .rubles
        case .dollars: return .dollars
        default: return nil
        }
    }
    var manualDuration: TimeInterval {
        switch self {
        case .cards, .rubles, .dollars: return 3.4
        case .shatter: return 3.0
        case .paintRoller: return 4.2
        default: return 1.6
        }
    }
    static func progress(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }
}

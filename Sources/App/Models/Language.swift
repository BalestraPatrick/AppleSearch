import Foundation

enum Language {
    case english
    case italian
    case german
    case french
    case all

    init(id: String) {
        switch id {
        case "en": self = .english
        case "it": self = .italian
        case "de": self = .german
        case "fr": self = .french
        case "all": self = .all
        default: fatalError()
        }
    }

    init(name: String) {
        switch name {
        case "🇺🇸 English": self = .english
        case "🇮🇹 Italian": self = .italian
        case "🇩🇪 German": self = .german
        case "🇫🇷 French": self = .french
        case "🌍 All": self = .all
        default: fatalError()
        }
    }

    var id: String {
        switch self {
        case .english: return "en"
        case .italian: return "it"
        case .german: return "de"
        case .french: return "fr"
        case .all: return "all"
        }
    }

    var name: String {
        switch self {
        case .english: return "🇺🇸 English"
        case .italian: return "🇮🇹 Italian"
        case .german: return "🇩🇪 German"
        case .french: return "🇫🇷 French"
        case .all: return "🌍 All"
        }
    }
}

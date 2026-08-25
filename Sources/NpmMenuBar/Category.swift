import Foundation

enum Category: String, CaseIterable, Identifiable {
    case npmCore, packages

    var id: String { rawValue }

    var l10nKey: L10nKey {
        switch self {
        case .npmCore: return .tabNpmCore
        case .packages: return .tabPackages
        }
    }
}

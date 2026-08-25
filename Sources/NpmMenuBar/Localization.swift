import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ja, en

    var id: String { rawValue }

    /// Concrete (non-"system") languages, for building an explicit picker choice list.
    static var concreteCases: [AppLanguage] { [.ja, .en] }

    var displayName: String {
        switch self {
        case .system: return ""
        case .ja: return "日本語"
        case .en: return "English"
        }
    }
}

enum L10nKey: String {
    case coreUpdateAvailableFormat
    case coreUpToDateFormat
    case packagesSectionFormat
    case upToDate
    case upgradeAll
    case upgradeAllPendingFormat
    case checkNow
    case preferences
    case quit
    case tabGeneral
    case tabNpmCore
    case tabPackages
    case launchAtLogin
    case language
    case languageSystemOption
    case checkFrequency
    case interval15m
    case interval30m
    case interval1h
    case interval3h
    case interval6h
    case interval12h
    case interval24h
    case autoUpgrade
    case autoUpgradeOnDescription
    case autoUpgradeOffDescription
    case notifyCoreTitle
    case notifyCoreBody
    case notifyCountBodyFormat
    case versionFormat
    case npmNotFoundWarning
    case packageVersionFormat
    case upgradeThis
    case excludeFromUpgrade
    /// Shared exclude-from-bulk-upgrade wording for the per-package Toggle,
    /// distinct from `excludeFromUpgrade` (a Button, npm-core-only — npm
    /// core has no Homebrew-side equivalent to align with).
    case excludeFromUpgradeAll
    case removeFromExclusion
    case excludedPackagesSectionFormat
    case coreOnHoldFormat
    case noExcludedPackages
    case upgradeFailedTitle
    case bundledNpmUpdateFormat
    case bundledSectionFormat
    case lastErrorFormat
}

@MainActor
final class Localizer: ObservableObject {
    static let shared = Localizer()

    /// The user's language preference: an explicit choice, or `.system` to
    /// always track the Mac's current language setting.
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "npmMenuBar.language")
            UserDefaults.standard.synchronize()
        }
    }

    /// The language actually used for lookups: `language` itself, or the
    /// resolved system language when `language == .system`.
    private var resolvedLanguage: AppLanguage {
        guard language == .system else { return language }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ja") ? .ja : .en
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "npmMenuBar.language"),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            language = .system
        }
    }

    func string(_ key: L10nKey) -> String {
        table[key]?[resolvedLanguage] ?? key.rawValue
    }

    func string(_ key: L10nKey, _ count: Int) -> String {
        let format = table[key]?[resolvedLanguage] ?? key.rawValue
        return String(format: format, count)
    }

    func string(_ key: L10nKey, _ value: String) -> String {
        let format = table[key]?[resolvedLanguage] ?? key.rawValue
        return String(format: format, value)
    }

    func string(_ key: L10nKey, _ value1: String, _ value2: String) -> String {
        let format = table[key]?[resolvedLanguage] ?? key.rawValue
        return String(format: format, value1, value2)
    }

    func string(_ key: L10nKey, _ value1: String, _ value2: String, _ value3: String) -> String {
        let format = table[key]?[resolvedLanguage] ?? key.rawValue
        return String(format: format, value1, value2, value3)
    }

    private let table: [L10nKey: [AppLanguage: String]] = [
        .coreUpdateAvailableFormat: [
            .ja: "npm: %@ → %@ (更新あり)",
            .en: "npm: %@ → %@ (Update available)"
        ],
        .coreUpToDateFormat: [
            .ja: "npm: %@ (最新)",
            .en: "npm: %@ (Latest)"
        ],
        .packagesSectionFormat: [.ja: "グローバルパッケージ (%d件)", .en: "Global Packages (%d)"],
        .upToDate: [.ja: "最新です", .en: "Up to date"],
        .upgradeAll: [.ja: "すべて更新", .en: "Upgrade All"],
        .upgradeAllPendingFormat: [.ja: "すべて更新 (%d件)", .en: "Upgrade All (%d)"],
        .checkNow: [.ja: "今すぐチェック", .en: "Check Now"],
        .preferences: [.ja: "環境設定...", .en: "Preferences..."],
        .quit: [.ja: "終了", .en: "Quit"],
        .tabGeneral: [.ja: "全般", .en: "General"],
        .tabNpmCore: [.ja: "npm本体", .en: "npm Core"],
        .tabPackages: [.ja: "グローバルパッケージ", .en: "Global Packages"],
        .launchAtLogin: [.ja: "ログイン時に自動起動", .en: "Launch at Login"],
        .language: [.ja: "言語", .en: "Language"],
        .languageSystemOption: [.ja: "システムに従う", .en: "Follow System"],
        .checkFrequency: [.ja: "チェック頻度", .en: "Check Frequency"],
        .interval15m: [.ja: "15分", .en: "15 minutes"],
        .interval30m: [.ja: "30分", .en: "30 minutes"],
        .interval1h: [.ja: "1時間", .en: "1 hour"],
        .interval3h: [.ja: "3時間", .en: "3 hours"],
        .interval6h: [.ja: "6時間", .en: "6 hours"],
        .interval12h: [.ja: "12時間", .en: "12 hours"],
        .interval24h: [.ja: "24時間", .en: "24 hours"],
        .autoUpgrade: [.ja: "自動でアップグレードする", .en: "Automatically upgrade"],
        .autoUpgradeOnDescription: [
            .ja: "更新を検出したら自動的にnpm installを実行します",
            .en: "When an update is detected, npm install runs automatically."
        ],
        .autoUpgradeOffDescription: [
            .ja: "更新を検出したら通知のみ行い、メニューから手動で実行します",
            .en: "When an update is detected, you'll only get a notification — run it manually from the menu."
        ],
        .notifyCoreTitle: [.ja: "npm本体", .en: "npm Core"],
        .notifyCoreBody: [.ja: "更新があります", .en: "An update is available"],
        .notifyCountBodyFormat: [.ja: "%d件の更新があります", .en: "%d update(s) available"],
        .versionFormat: [.ja: "バージョン %@", .en: "Version %@"],
        .npmNotFoundWarning: [
            .ja: "npmコマンドが見つかりません(ログインシェルのPATH設定を確認してください)",
            .en: "npm command not found (check your login shell's PATH configuration)"
        ],
        .packageVersionFormat: [.ja: "%@ (%@ → %@)", .en: "%@ (%@ → %@)"],
        .upgradeThis: [.ja: "このパッケージを更新", .en: "Upgrade This Package"],
        .excludeFromUpgrade: [.ja: "このバージョンで据え置く", .en: "Hold at This Version"],
        .excludeFromUpgradeAll: [.ja: "「すべて更新」の対象外にする", .en: "Exclude from Upgrade All"],
        .removeFromExclusion: [.ja: "解除", .en: "Remove"],
        .excludedPackagesSectionFormat: [.ja: "除外中のパッケージ (%d件)", .en: "Excluded Packages (%d)"],
        .coreOnHoldFormat: [
            .ja: "npm: %@ → %@ (据え置き中)",
            .en: "npm: %@ → %@ (On Hold)"
        ],
        .noExcludedPackages: [.ja: "対象はありません", .en: "None"],
        .upgradeFailedTitle: [.ja: "更新に失敗しました", .en: "Upgrade Failed"],
        .bundledNpmUpdateFormat: [
            .ja: "npm (Node同梱): %@ → %@ (更新あり)",
            .en: "npm (Node-bundled): %@ → %@ (Update available)"
        ],
        .bundledSectionFormat: [.ja: "Node同梱 (%d件)", .en: "Node-bundled (%d)"],
        .lastErrorFormat: [.ja: "⚠️ 更新失敗: %@", .en: "⚠️ Upgrade failed: %@"],
    ]
}

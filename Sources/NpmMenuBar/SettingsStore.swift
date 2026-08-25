import Foundation

final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    func intervalMinutes(for category: Category) -> Double {
        let key = key(category, "intervalMinutes")
        if defaults.object(forKey: key) == nil {
            return defaultIntervalMinutes(category)
        }
        return defaults.double(forKey: key)
    }

    func interval(for category: Category) -> TimeInterval {
        intervalMinutes(for: category) * 60
    }

    func setInterval(_ minutes: Double, for category: Category) {
        defaults.set(minutes, forKey: key(category, "intervalMinutes"))
        defaults.synchronize()
    }

    func autoUpgrade(for category: Category) -> Bool {
        defaults.bool(forKey: key(category, "auto"))
    }

    func setAutoUpgrade(_ value: Bool, for category: Category) {
        defaults.set(value, forKey: key(category, "auto"))
        defaults.synchronize()
    }

    /// Packages the user wants to hold at their current version. Held out of
    /// "Upgrade All" / auto-upgrade and out of the pending count entirely, so
    /// pinning a version doesn't leave a permanent badge/notification nagging
    /// about it. `npm` itself uses this same set, keyed by the name "npm".
    func excludedPackages() -> Set<String> {
        Set(defaults.stringArray(forKey: "npmMenuBar.excludedPackages") ?? [])
    }

    func isExcluded(_ packageName: String) -> Bool {
        excludedPackages().contains(packageName)
    }

    func setExcluded(_ packageName: String, _ excluded: Bool) {
        var names = excludedPackages()
        if excluded {
            names.insert(packageName)
        } else {
            names.remove(packageName)
        }
        defaults.set(Array(names), forKey: "npmMenuBar.excludedPackages")
        defaults.synchronize()
    }

    private func defaultIntervalMinutes(_ category: Category) -> Double {
        switch category {
        case .npmCore: return 180
        case .packages: return 180
        }
    }

    private func key(_ category: Category, _ suffix: String) -> String {
        "npmMenuBar.\(category.rawValue).\(suffix)"
    }
}

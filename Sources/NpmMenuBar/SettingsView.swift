import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: NpmMonitor
    @ObservedObject private var l10n = Localizer.shared

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label(l10n.string(.tabGeneral), systemImage: "gearshape") }
            CategorySettingsView(category: .npmCore, monitor: monitor)
                .tabItem { Label(l10n.string(.tabNpmCore), systemImage: "shippingbox") }
            CategorySettingsView(category: .packages, monitor: monitor)
                .tabItem { Label(l10n.string(.tabPackages), systemImage: "cube.box") }
        }
        .padding()
        .frame(width: 380, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var l10n = Localizer.shared
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        Form {
            Toggle(l10n.string(.launchAtLogin), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }

            Picker(l10n.string(.language), selection: $l10n.language) {
                Text(l10n.string(.languageSystemOption)).tag(AppLanguage.system)
                ForEach(AppLanguage.concreteCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }

            Section {
                HStack {
                    Text(AppVersion.appName)
                    Spacer()
                    Text(l10n.string(.versionFormat, AppVersion.displayVersion))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

struct CategorySettingsView: View {
    let category: Category
    @ObservedObject var monitor: NpmMonitor
    @ObservedObject private var l10n = Localizer.shared
    @State private var intervalMinutes: Double
    @State private var auto: Bool

    private var intervalOptions: [(L10nKey, Double)] {
        [
            (.interval15m, 15), (.interval30m, 30), (.interval1h, 60), (.interval3h, 180),
            (.interval6h, 360), (.interval12h, 720), (.interval24h, 1440)
        ]
    }

    init(category: Category, monitor: NpmMonitor) {
        self.category = category
        self.monitor = monitor
        _intervalMinutes = State(initialValue: SettingsStore.shared.intervalMinutes(for: category))
        _auto = State(initialValue: SettingsStore.shared.autoUpgrade(for: category))
    }

    var body: some View {
        Form {
            Picker(l10n.string(.checkFrequency), selection: $intervalMinutes) {
                ForEach(intervalOptions, id: \.1) { option in
                    Text(l10n.string(option.0)).tag(option.1)
                }
            }
            .onChange(of: intervalMinutes) { _, newValue in
                SettingsStore.shared.setInterval(newValue, for: category)
                monitor.reschedule(category)
            }

            Toggle(l10n.string(.autoUpgrade), isOn: $auto)
                .onChange(of: auto) { _, newValue in
                    SettingsStore.shared.setAutoUpgrade(newValue, for: category)
                }

            Text(l10n.string(auto ? .autoUpgradeOnDescription : .autoUpgradeOffDescription))
                .font(.caption)
                .foregroundStyle(.secondary)

            if category == .packages {
                // "npm" itself is held through the separate npm-core hold
                // menu, not this per-package list, so it's filtered out here.
                let excludedNames = monitor.excludedNames.filter { $0 != "npm" }
                Section(l10n.string(.excludedPackagesSectionFormat, excludedNames.count)) {
                    if excludedNames.isEmpty {
                        Text(l10n.string(.noExcludedPackages))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(excludedNames, id: \.self) { pkg in
                                    HStack {
                                        Text(pkg)
                                        Spacer()
                                        Button(l10n.string(.removeFromExclusion)) {
                                            monitor.setExcluded(pkg, false)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
            }
        }
        .padding()
    }
}

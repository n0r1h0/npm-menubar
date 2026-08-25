import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var monitor: NpmMonitor
    @ObservedObject private var l10n = Localizer.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("\(AppVersion.appName) — \(l10n.string(.versionFormat, AppVersion.displayVersion))")
            .foregroundStyle(.secondary)

        if monitor.npmNotFound {
            Divider()
            Text(l10n.string(.npmNotFoundWarning))
                .foregroundStyle(.secondary)
        }

        Divider()

        if let core = monitor.npmCoreOutdated {
            Menu(l10n.string(.coreUpdateAvailableFormat, core.current, core.latest)) {
                Button(l10n.string(.upgradeThis)) { monitor.upgradeCore() }
                Button(l10n.string(.excludeFromUpgrade)) { monitor.setExcluded("npm", true) }
            }
        } else if let held = monitor.excludedCoreOutdated {
            Menu(l10n.string(.coreOnHoldFormat, held.current, held.latest)) {
                Button(l10n.string(.upgradeThis)) { monitor.upgradeCore() }
                Button(l10n.string(.removeFromExclusion)) { monitor.setExcluded("npm", false) }
            }
        } else {
            Text(l10n.string(.coreUpToDateFormat, currentNpmVersion))
        }

        Divider()

        if monitor.npmCoreOutdated != nil || !monitor.upgradablePackages.isEmpty {
            Button(l10n.string(.upgradeAllPendingFormat, totalPendingCount)) {
                monitor.upgradeAllPending()
            }
            Divider()
        }

        Menu(l10n.string(.packagesSectionFormat, monitor.packagesOutdated.count)) {
            if monitor.packagesOutdated.isEmpty {
                Text(l10n.string(.upToDate))
            } else {
                if !monitor.upgradablePackages.isEmpty {
                    Button(l10n.string(.upgradeAll)) { monitor.upgradeAllPackages() }
                    Divider()
                }
                ForEach(monitor.packagesOutdated) { pkg in
                    packageMenu(pkg: pkg)
                }
            }
        }

        if monitor.bundledNpmOutdated != nil || !monitor.bundledPackagesOutdated.isEmpty {
            Divider()
            Menu(l10n.string(.bundledSectionFormat, bundledPendingCount)) {
                if let bundled = monitor.bundledNpmOutdated {
                    Menu(l10n.string(.bundledNpmUpdateFormat, bundled.current, bundled.latest)) {
                        Button(l10n.string(.upgradeThis)) { monitor.upgradeBundledNpm() }
                    }
                    if !monitor.bundledPackagesOutdated.isEmpty {
                        Divider()
                    }
                }
                if !monitor.bundledPackagesOutdated.isEmpty {
                    Button(l10n.string(.upgradeAll)) { monitor.upgradeAllBundledPackages() }
                    Divider()
                    ForEach(monitor.bundledPackagesOutdated) { pkg in
                        Button(l10n.string(.packageVersionFormat, pkg.name, pkg.current, pkg.latest)) {
                            monitor.upgradeBundledPackage(package: pkg.name, toVersion: pkg.latest)
                        }
                    }
                }
            }
        }

        if let error = monitor.lastUpgradeError {
            Divider()
            Text(l10n.string(.lastErrorFormat, error))
        }

        Divider()

        Button(l10n.string(.checkNow)) {
            Task { await monitor.checkAll() }
        }

        Button(l10n.string(.preferences)) {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        Button(l10n.string(.quit)) {
            NSApplication.shared.terminate(nil)
        }
    }

    /// A 📌 marker on the name plus a shared "exclude from Upgrade All"
    /// toggle, instead of a separate on-hold list — held packages stay put
    /// in the same menu.
    @ViewBuilder
    private func packageMenu(pkg: OutdatedPackage) -> some View {
        let excluded = monitor.isExcluded(pkg.name)
        let label = l10n.string(.packageVersionFormat, pkg.name, pkg.current, pkg.latest)
        Menu(excluded ? "📌 \(label)" : label) {
            Button(l10n.string(.upgradeThis)) { monitor.upgrade(package: pkg.name, toVersion: pkg.latest) }
            Toggle(l10n.string(.excludeFromUpgradeAll), isOn: Binding(
                get: { monitor.isExcluded(pkg.name) },
                set: { monitor.setExcluded(pkg.name, $0) }
            ))
        }
    }

    private var currentNpmVersion: String {
        monitor.npmCoreOutdated?.current ?? monitor.excludedCoreOutdated?.current ?? ""
    }

    private var totalPendingCount: Int {
        monitor.upgradablePackages.count + (monitor.npmCoreOutdated != nil ? 1 : 0)
    }

    private var bundledPendingCount: Int {
        monitor.bundledPackagesOutdated.count + (monitor.bundledNpmOutdated != nil ? 1 : 0)
    }
}

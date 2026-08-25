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

        if monitor.npmCoreOutdated != nil || !monitor.packagesOutdated.isEmpty {
            Button(l10n.string(.upgradeAllPendingFormat, totalPendingCount)) {
                monitor.upgradeAllPending()
            }
            Divider()
        }

        Menu(l10n.string(.packagesSectionFormat, monitor.packagesOutdated.count)) {
            if monitor.packagesOutdated.isEmpty {
                Text(l10n.string(.upToDate))
            } else {
                Button(l10n.string(.upgradeAll)) { monitor.upgradeAllPackages() }
                Divider()
                ForEach(monitor.packagesOutdated) { pkg in
                    Menu(l10n.string(.packageVersionFormat, pkg.name, pkg.current, pkg.latest)) {
                        Button(l10n.string(.upgradeThis)) { monitor.upgrade(package: pkg.name, toVersion: pkg.latest) }
                        Button(l10n.string(.excludeFromUpgrade)) { monitor.setExcluded(pkg.name, true) }
                    }
                }
            }
        }

        if !monitor.excludedPackagesOutdated.isEmpty {
            Menu(l10n.string(.excludedSectionFormat, monitor.excludedPackagesOutdated.count)) {
                ForEach(monitor.excludedPackagesOutdated) { pkg in
                    Menu(l10n.string(.packageVersionFormat, pkg.name, pkg.current, pkg.latest)) {
                        Button(l10n.string(.upgradeThis)) { monitor.upgrade(package: pkg.name, toVersion: pkg.latest) }
                        Button(l10n.string(.removeFromExclusion)) { monitor.setExcluded(pkg.name, false) }
                    }
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

    private var currentNpmVersion: String {
        monitor.npmCoreOutdated?.current ?? monitor.excludedCoreOutdated?.current ?? ""
    }

    private var totalPendingCount: Int {
        monitor.packagesOutdated.count + (monitor.npmCoreOutdated != nil ? 1 : 0)
    }

    private var bundledPendingCount: Int {
        monitor.bundledPackagesOutdated.count + (monitor.bundledNpmOutdated != nil ? 1 : 0)
    }
}

import Foundation
import Combine
import UserNotifications

struct OutdatedPackage: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let current: String
    let latest: String
}

@MainActor
final class NpmMonitor: ObservableObject {
    @Published var npmCoreOutdated: OutdatedPackage?
    /// Every outdated global package, including ones the user pinned — they
    /// stay in this one list (marked with 📌 in the menu) rather than being
    /// split into a separate "on hold" collection.
    @Published var packagesOutdated: [OutdatedPackage] = []
    /// Outdated entries the user chose to hold at their current version.
    /// Kept visible (so they can be un-excluded) but excluded from the
    /// pending badge/count, notifications, and "Upgrade All" / auto-upgrade.
    @Published var excludedCoreOutdated: OutdatedPackage?
    /// Every package name registered as held, regardless of whether it's
    /// currently outdated — this is what the Preferences window lists.
    @Published private(set) var excludedNames: [String] = []
    /// The npm bundled inside the Node.js install on disk — a separate copy
    /// from the Volta-managed npm that `npmCoreOutdated` tracks. Only
    /// populated when Volta is present (without Volta there's just one
    /// npm). Deliberately kept out of "Upgrade All": upgrading this isn't
    /// something most people need, and `volta run --bundled-npm` is a
    /// distinct, more surprising operation than the normal upgrade path.
    @Published var bundledNpmOutdated: OutdatedPackage?
    /// Global packages as seen by that same bundled npm — i.e. packages
    /// installed via `volta run --bundled-npm -- npm install -g ...`
    /// rather than through Volta's own toolchain. Independent list from
    /// `packagesOutdated`; also excluded from "Upgrade All".
    @Published var bundledPackagesOutdated: [OutdatedPackage] = []
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var npmNotFound: Bool = false
    /// Set whenever `npm install -g` exits non-zero. Shown directly in the
    /// dropdown menu — notifications require permission the user may not
    /// have granted, so the menu is the one place a failure is guaranteed
    /// to be visible. Cleared at the start of the next upgrade attempt.
    @Published private(set) var lastUpgradeError: String?

    private var busyCount: Int = 0
    private var timers: [Category: Timer] = [:]
    private var lastOutdated: [String: OutdatedPackage] = [:]
    private var voltaAvailable: Bool?
    private let settings = SettingsStore.shared
    private let loginShell: String

    init() {
        self.loginShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        excludedNames = settings.excludedPackages().sorted()
        for category in Category.allCases {
            reschedule(category)
        }
        Task { await checkAll() }
    }

    func reschedule(_ category: Category) {
        timers[category]?.invalidate()
        let interval = settings.interval(for: category)
        timers[category] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.check(category) }
        }
    }

    func checkAll() async {
        for category in Category.allCases {
            await check(category)
        }
    }

    func check(_ category: Category) async {
        beginBusy()
        defer { endBusy() }
        let outdated = await fetchOutdated()
        lastOutdated = outdated
        switch category {
        case .npmCore:
            applyCoreResult(outdated)
            await checkBundled()
        case .packages:
            applyPackagesResult(outdated)
        }
    }

    /// Separate from the Volta-managed check above: this asks the npm
    /// actually bundled inside the Node.js install (`volta run
    /// --bundled-npm -- npm outdated -g`) about both itself and its own
    /// view of global packages — packages installed via that bundled npm
    /// rather than through Volta's toolchain. Upgrading through Volta's
    /// normal path never touches either of these.
    private func checkBundled() async {
        guard await isVoltaAvailable() else {
            bundledNpmOutdated = nil
            bundledPackagesOutdated = []
            return
        }
        let result = await runShellLogin("volta run --bundled-npm -- npm outdated -g --json")
        guard let rawPackages = parseOutdatedJSON(result.output) else {
            bundledNpmOutdated = nil
            bundledPackagesOutdated = []
            return
        }
        let outdatedOnly = rawPackages.values.filter { $0.current != $0.latest }
        bundledNpmOutdated = outdatedOnly.first { $0.name == "npm" }
        bundledPackagesOutdated = outdatedOnly
            .filter { $0.name != "npm" }
            .sorted { $0.name < $1.name }
    }

    func upgradeBundledNpm() {
        guard let latest = bundledNpmOutdated?.latest else { return }
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            let result = await runBundledUpgrade(["npm@\(latest)"])
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await checkBundled()
        }
    }

    func upgradeBundledPackage(package: String, toVersion version: String) {
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            let result = await runBundledUpgrade(["\(package)@\(version)"])
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await checkBundled()
        }
    }

    func upgradeAllBundledPackages() {
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            guard !bundledPackagesOutdated.isEmpty else { return }
            let specs = bundledPackagesOutdated.map { "\($0.name)@\($0.latest)" }
            let result = await runBundledUpgrade(specs)
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await checkBundled()
        }
    }

    func isExcluded(_ packageName: String) -> Bool {
        settings.isExcluded(packageName)
    }

    /// `packagesOutdated` minus the ones the user pinned via exclusion —
    /// this is what "Upgrade All" / auto-upgrade actually acts on.
    var upgradablePackages: [OutdatedPackage] {
        let excluded = settings.excludedPackages()
        return packagesOutdated.filter { !excluded.contains($0.name) }
    }

    /// Re-splits the last fetched result under the new exclusion state
    /// without re-running npm, so toggling exclusion from the menu feels
    /// instant.
    func setExcluded(_ packageName: String, _ excluded: Bool) {
        settings.setExcluded(packageName, excluded)
        excludedNames = settings.excludedPackages().sorted()
        applyCoreResult(lastOutdated)
        applyPackagesResult(lastOutdated)
    }

    /// Upgrades to the specific version npm's own `outdated` check reported,
    /// not the abstract `@latest` dist-tag. The two can disagree: `outdated`
    /// picks the newest version whose `engines` range the current Node.js
    /// actually satisfies, while `@latest` is the dist-tag's absolute
    /// newest — which can require a newer Node.js than is installed. Using
    /// `@latest` there silently "succeeds" (exit 0) without actually
    /// updating anything, which looks like this app doing nothing.
    func upgradeCore() {
        guard let latest = (npmCoreOutdated ?? excludedCoreOutdated)?.latest else { return }
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            let result = await runUpgrade(["npm@\(latest)"])
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await check(.npmCore)
        }
    }

    func upgrade(package: String, toVersion version: String) {
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            let result = await runUpgrade(["\(package)@\(version)"])
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await check(.packages)
        }
    }

    func upgradeAllPackages() {
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            let targets = upgradablePackages
            guard !targets.isEmpty else { return }
            let specs = targets.map { "\($0.name)@\($0.latest)" }
            let result = await runUpgrade(specs)
            if result.status != 0 {
                reportUpgradeFailure(result.output)
            }
            await check(.packages)
        }
    }

    /// The top-level "Upgrade All" — npm itself first, then packages, so
    /// packages install under the npm version you're about to be running
    /// rather than the one you're replacing.
    func upgradeAllPending() {
        Task {
            beginBusy()
            defer { endBusy() }
            lastUpgradeError = nil
            if let core = npmCoreOutdated {
                let coreResult = await runUpgrade(["npm@\(core.latest)"])
                if coreResult.status != 0 {
                    reportUpgradeFailure(coreResult.output)
                }
            }
            let targets = upgradablePackages
            if !targets.isEmpty {
                let specs = targets.map { "\($0.name)@\($0.latest)" }
                let packagesResult = await runUpgrade(specs)
                if packagesResult.status != 0 {
                    reportUpgradeFailure(packagesResult.output)
                }
            }
            await check(.npmCore)
            await check(.packages)
        }
    }

    /// `npm install -g` can exit non-zero after partially applying changes
    /// (e.g. a version manager's shim-linking step failing), so surface the
    /// last non-empty line of combined stdout/stderr instead of silently
    /// re-checking and leaving the user to wonder why nothing changed.
    private func reportUpgradeFailure(_ combinedOutput: String) {
        let lastLine = combinedOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty }) ?? ""
        lastUpgradeError = lastLine
        notify(title: Localizer.shared.string(.upgradeFailedTitle), body: lastLine)
    }

    private func beginBusy() {
        busyCount += 1
        isBusy = busyCount > 0
    }

    private func endBusy() {
        busyCount = max(0, busyCount - 1)
        isBusy = busyCount > 0
    }

    /// Runs `npm outdated -g --json` once and returns every outdated entry,
    /// keyed by package name. `npm` itself shows up as a normal entry here,
    /// which is how it gets split out as "core" below.
    private func fetchOutdated() async -> [String: OutdatedPackage] {
        let result = await runNpm(["outdated", "-g", "--json"])
        npmNotFound = result.status == -1
        guard let rawPackages = parseOutdatedJSON(result.output) else {
            return [:]
        }
        let voltaVersions = await fetchVoltaManagedVersions()
        var packages: [String: OutdatedPackage] = [:]
        for (name, info) in rawPackages {
            let current = voltaVersions[name] ?? info.current
            guard current != info.latest else { continue }
            packages[name] = OutdatedPackage(name: name, current: current, latest: info.latest)
        }
        return packages
    }

    /// Parses `npm outdated -g --json` output into every reported entry
    /// (including ones where current == latest), keyed by package name.
    private func parseOutdatedJSON(_ output: String) -> [String: OutdatedPackage]? {
        guard let jsonSubstring = extractJSONObject(from: output),
              let data = jsonSubstring.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return nil
        }
        var packages: [String: OutdatedPackage] = [:]
        for (name, info) in json {
            let current = info["current"] as? String ?? "?"
            let latest = info["latest"] as? String ?? "?"
            packages[name] = OutdatedPackage(name: name, current: current, latest: latest)
        }
        return packages
    }

    /// When Volta manages global tools, `npm outdated -g`'s "current" can
    /// reflect the (unused) tool files bundled inside the Node.js install on
    /// disk rather than the version Volta actually runs through its shims —
    /// observed firsthand for both npm itself (`outdated` said 10.9.3,
    /// `npm --version` said 11.19.0) and corepack (`outdated` said 0.34.0,
    /// `corepack --version` said 0.34.7). `volta list --format plain`
    /// reports what's actually pinned and running, so it takes priority
    /// over `outdated`'s "current" whenever Volta lists the same name.
    private func fetchVoltaManagedVersions() async -> [String: String] {
        guard await isVoltaAvailable() else { return [:] }
        let result = await runShellLogin("volta list --format plain")
        guard result.status == 0 else { return [:] }
        var versions: [String: String] = [:]
        for line in result.output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 1)
            guard fields.count == 2, fields[0] == "package" || fields[0] == "package-manager" else { continue }
            guard let nameVersion = fields[1].split(separator: " ").first,
                  let atIndex = nameVersion.lastIndex(of: "@") else { continue }
            let name = String(nameVersion[..<atIndex])
            let version = String(nameVersion[nameVersion.index(after: atIndex)...])
            versions[name] = version
        }
        return versions
    }

    /// Interactive login shells can prepend prompt-init noise (from
    /// oh-my-zsh, powerlevel10k, etc.) to stdout, so pull out just the
    /// `{...}` object rather than assuming `npm`'s output is the only thing
    /// on the pipe.
    private func extractJSONObject(from output: String) -> String? {
        guard let start = output.firstIndex(of: "{"), let end = output.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(output[start...end])
    }

    private func applyCoreResult(_ outdated: [String: OutdatedPackage]) {
        guard let entry = outdated["npm"] else {
            npmCoreOutdated = nil
            excludedCoreOutdated = nil
            return
        }

        if settings.isExcluded(entry.name) {
            npmCoreOutdated = nil
            excludedCoreOutdated = entry
            return
        }
        excludedCoreOutdated = nil

        let wasPending = npmCoreOutdated != nil
        npmCoreOutdated = entry

        if !wasPending {
            notify(title: Localizer.shared.string(.notifyCoreTitle), body: Localizer.shared.string(.notifyCoreBody))
        }

        if settings.autoUpgrade(for: .npmCore) {
            Task {
                let result = await runUpgrade(["npm@\(entry.latest)"])
                if result.status == 0 {
                    npmCoreOutdated = nil
                } else {
                    reportUpgradeFailure(result.output)
                }
            }
        }
    }

    private func applyPackagesResult(_ outdated: [String: OutdatedPackage]) {
        let all = outdated.values
            .filter { $0.name != "npm" }
            .sorted { $0.name < $1.name }
        let excludedNames = settings.excludedPackages()
        let upgradable = all.filter { !excludedNames.contains($0.name) }
        let previousUpgradableCount = packagesOutdated
            .filter { !excludedNames.contains($0.name) }
            .count

        packagesOutdated = all

        if !upgradable.isEmpty && upgradable.count != previousUpgradableCount {
            notify(
                title: Localizer.shared.string(.tabPackages),
                body: Localizer.shared.string(.notifyCountBodyFormat, upgradable.count)
            )
        }

        if !upgradable.isEmpty && settings.autoUpgrade(for: .packages) {
            Task {
                let specs = upgradable.map { "\($0.name)@\($0.latest)" }
                let result = await runUpgrade(specs)
                if result.status == 0 {
                    let upgradedNames = Set(upgradable.map { $0.name })
                    packagesOutdated = packagesOutdated.filter { !upgradedNames.contains($0.name) }
                } else {
                    reportUpgradeFailure(result.output)
                }
            }
        }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// npm is commonly managed by a version manager (Volta, nvm, fnm, ...)
    /// that shims PATH inside shell init files, so instead of guessing a
    /// fixed install path (as Homebrew's own binary allows), every command
    /// runs through the user's login shell to resolve `npm` the same way an
    /// interactive terminal would. Version managers often add their PATH
    /// entry in `.zshrc` rather than `.zprofile`/`.zshenv`, and `.zshrc` is
    /// only sourced for an *interactive* shell — so a plain login shell
    /// (`-l` without `-i`) can silently resolve a different, stale `npm`.
    private func runNpm(_ args: [String]) async -> (status: Int32, output: String) {
        let command = (["npm"] + args).map(shellQuote).joined(separator: " ")
        return await runShellLogin(command)
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func isVoltaAvailable() async -> Bool {
        if let cached = voltaAvailable { return cached }
        let result = await runShellLogin("command -v volta")
        let available = result.status == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        voltaAvailable = available
        return available
    }

    /// Installs/upgrades `name@version` specs. Volta owns global tool
    /// installs when present, and running `npm install -g` alongside it can
    /// leave Volta's own bookkeeping (`volta list`) out of sync with what's
    /// actually on disk — observed firsthand: Volta reported a package as
    /// already at the new version while its on-disk package.json was still
    /// the old one, so the "upgrade" silently no-op'd forever after. Falls
    /// back to `npm install -g` when Volta isn't the one managing globals
    /// (nvm, fnm, a plain Node.js install, ...).
    private func runUpgrade(_ specs: [String]) async -> (status: Int32, output: String) {
        if await isVoltaAvailable() {
            let command = (["volta", "install"] + specs).map(shellQuote).joined(separator: " ")
            return await runShellLogin(command)
        }
        return await runNpm(["install", "-g"] + specs)
    }

    /// Upgrades `name@version` specs through the npm bundled inside the
    /// Node.js install. `volta run --bundled-npm -- npm install -g ...`
    /// looks right but doesn't work: it only swaps which npm *binary*
    /// runs — Volta's own `npm install -g` interception still kicks in
    /// underneath, so the command reports success ("added 1 package") and
    /// updates Volta's bookkeeping (`volta list`) while the actual files
    /// on disk never change (observed firsthand with corepack). The only
    /// way that actually writes to the bundled npm's own node_modules is
    /// invoking its `npm-cli.js` directly with `node`, bypassing Volta's
    /// npm shim entirely, and passing `--prefix` explicitly (Volta's node
    /// shim would otherwise still intercept a bare `npm` on PATH).
    private func runBundledUpgrade(_ specs: [String]) async -> (status: Int32, output: String) {
        let whichNode = await runShellLogin("volta which node")
        let nodeBinPath = whichNode.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard whichNode.status == 0, !nodeBinPath.isEmpty else {
            return (-1, "volta which node failed: \(whichNode.output)")
        }
        let nodeInstallDir = URL(fileURLWithPath: nodeBinPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let npmCliJs = nodeInstallDir + "/lib/node_modules/npm/bin/npm-cli.js"
        let args = [nodeBinPath, npmCliJs, "install", "-g"] + specs + ["--prefix", nodeInstallDir]
        let command = args.map(shellQuote).joined(separator: " ")
        return await runShellLogin(command)
    }

    /// Combines stdout and stderr into one string: `fetchOutdated`'s JSON
    /// extraction only looks for a `{...}` substring so stray stderr lines
    /// don't confuse it, and upgrade failures (e.g. a version manager's
    /// shim-linking error) are almost always reported on stderr alone.
    private func runShellLogin(_ command: String) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [loginShell] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: loginShell)
                process.arguments = ["-i", "-l", "-c", command]
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, ""))
                    return
                }
                process.waitUntilExit()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errData, encoding: .utf8) ?? ""
                let combined = errorOutput.isEmpty ? output : output + "\n" + errorOutput
                continuation.resume(returning: (process.terminationStatus, combined))
            }
        }
    }
}

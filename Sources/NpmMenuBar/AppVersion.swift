import Foundation

enum AppVersion {
    static let appName = "npm MenuBar"

    /// Bump this together with CFBundleShortVersionString in Info.plist and
    /// Scripts/build-app.sh whenever a release is cut.
    static let releaseVersion = "0.2"

    /// `swift build` (no `-c release`) defines DEBUG, so a dev build always
    /// shows a random suffix to make it obvious it isn't the release binary.
    static let displayVersion: String = {
        #if DEBUG
        return "\(releaseVersion)-dev\(Int.random(in: 1000...9999))"
        #else
        return releaseVersion
        #endif
    }()
}

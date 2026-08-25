import SwiftUI
import AppKit

@main
struct NpmMenuBarApp: App {
    @StateObject private var monitor = NpmMonitor()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(monitor: monitor)
        } label: {
            MenuBarLabelView(monitor: monitor)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(monitor: monitor)
        }
    }
}

import SwiftUI
import AppKit

private enum MenuBarIconFrames {
    /// Number of frames for one direction of the fade (the full cycle mirrors this back).
    static let oneWayStepCount = 10
    private static let minAlpha = 0.25

    private static var cache: [String: [NSImage]] = [:]

    static func frames(for symbolName: String) -> [NSImage] {
        if let cached = cache[symbolName] { return cached }
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return []
        }
        let images = breathingAlphas().map { render(base, alpha: $0) }
        cache[symbolName] = images
        return images
    }

    /// A palindrome sequence (1.0 down to minAlpha, then back up) baked into
    /// discrete frames, so the label just steps through an array — no
    /// runtime opacity modifier is involved.
    private static func breathingAlphas() -> [Double] {
        let down = (0..<oneWayStepCount).map { step in
            1.0 - (1.0 - minAlpha) * Double(step) / Double(oneWayStepCount - 1)
        }
        return down + down.reversed()
    }

    private static func render(_ base: NSImage, alpha: Double) -> NSImage {
        let size = base.size
        let image = NSImage(size: size)
        image.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: alpha)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var monitor: NpmMonitor
    @State private var frameIndex = 0
    @State private var blinkTimer: Timer?

    private var hasPending: Bool {
        monitor.npmCoreOutdated != nil || !monitor.packagesOutdated.isEmpty
    }

    private var busyFrames: [NSImage] {
        MenuBarIconFrames.frames(for: hasPending ? "shippingbox.fill" : "shippingbox")
    }

    var body: some View {
        HStack(spacing: 3) {
            if monitor.isBusy, !busyFrames.isEmpty {
                Image(nsImage: busyFrames[frameIndex % busyFrames.count])
            } else {
                Image(systemName: hasPending ? "shippingbox.fill" : "shippingbox")
            }
            if monitor.npmCoreOutdated != nil {
                Text("!")
            }
            if !monitor.packagesOutdated.isEmpty {
                Text("\(monitor.packagesOutdated.count)")
            }
        }
        .onAppear {
            updateBlink(monitor.isBusy)
        }
        .onChange(of: monitor.isBusy) { _, busy in
            updateBlink(busy)
        }
        .onDisappear {
            stopBlink()
        }
    }

    private func updateBlink(_ busy: Bool) {
        stopBlink()
        guard busy else { return }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            Task { @MainActor in
                frameIndex += 1
            }
        }
    }

    private func stopBlink() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        frameIndex = 0
    }
}

import AppKit

let projectDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resourcesDir = projectDir.appendingPathComponent("Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

let fm = FileManager.default
try? fm.removeItem(at: iconsetDir)
try! fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
try! fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: size).fill()
        draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}

func renderIcon(size: Int) -> NSImage {
    let canvas = NSImage(size: NSSize(width: size, height: size))
    canvas.lockFocus()

    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.2237
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(calibratedRed: 0.80, green: 0.13, blue: 0.20, alpha: 1.0).setFill()
    bgPath.fill()

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.56, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let tinted = symbol.tinted(with: NSColor.white)
        let symbolSize = tinted.size
        let origin = NSPoint(
            x: (CGFloat(size) - symbolSize.width) / 2,
            y: (CGFloat(size) - symbolSize.height) / 2
        )
        tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    canvas.unlockFocus()
    return canvas
}

func savePNG(_ image: NSImage, size: Int, to url: URL) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap rep")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(url.lastPathComponent)")
    }
    try! png.write(to: url)
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

for (size, name) in sizes {
    let image = renderIcon(size: size)
    let url = iconsetDir.appendingPathComponent("\(name).png")
    savePNG(image, size: size, to: url)
    print("Generated \(name).png (\(size)x\(size))")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try! process.run()
process.waitUntilExit()

print("Wrote \(icnsURL.path)")
print("Kept source images in \(iconsetDir.path)")

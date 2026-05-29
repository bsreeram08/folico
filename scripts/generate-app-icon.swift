import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "dist/Folico.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("Folico.iconset", isDirectory: true)

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSpecs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in iconSpecs {
    let image = renderIcon(size: spec.pixels)
    let destination = iconsetURL.appendingPathComponent(spec.name)
    try writePNG(image, to: destination)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "FolicoIconGenerator",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed to create \(outputURL.path)"]
    )
}

try? fileManager.removeItem(at: iconsetURL)

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let context = NSGraphicsContext.current?.cgContext
    context?.setShadow(
        offset: CGSize(width: 0, height: -size * 0.025),
        blur: size * 0.045,
        color: NSColor.black.withAlphaComponent(0.22).cgColor
    )

    let backgroundRect = NSRect(x: size * 0.08, y: size * 0.08, width: size * 0.84, height: size * 0.84)
    let backgroundPath = roundedRect(backgroundRect, radius: size * 0.19)
    verticalGradient(
        top: NSColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0),
        bottom: NSColor(red: 0.03, green: 0.22, blue: 0.68, alpha: 1.0)
    )
    .draw(in: backgroundPath, angle: 90)

    context?.setShadow(offset: .zero, blur: 0)

    let tabRect = NSRect(x: size * 0.24, y: size * 0.61, width: size * 0.23, height: size * 0.12)
    let bodyRect = NSRect(x: size * 0.20, y: size * 0.27, width: size * 0.60, height: size * 0.40)
    NSColor.white.withAlphaComponent(0.92).setFill()
    roundedRect(tabRect, radius: size * 0.035).fill()
    roundedRect(bodyRect, radius: size * 0.07).fill()

    let sparkColor = NSColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0)
    sparkColor.setFill()
    drawSpark(center: CGPoint(x: size * 0.61, y: size * 0.47), radius: size * 0.11)

    NSColor.white.setStroke()
    let smile = NSBezierPath()
    smile.lineWidth = max(1.0, size * 0.025)
    smile.move(to: CGPoint(x: size * 0.36, y: size * 0.40))
    smile.curve(
        to: CGPoint(x: size * 0.52, y: size * 0.40),
        controlPoint1: CGPoint(x: size * 0.40, y: size * 0.35),
        controlPoint2: CGPoint(x: size * 0.48, y: size * 0.35)
    )
    smile.stroke()

    return image
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func verticalGradient(top: NSColor, bottom: NSColor) -> NSGradient {
    NSGradient(starting: bottom, ending: top)!
}

func drawSpark(center: CGPoint, radius: CGFloat) {
    let path = NSBezierPath()
    let points = [
        CGPoint(x: center.x, y: center.y + radius),
        CGPoint(x: center.x + radius * 0.25, y: center.y + radius * 0.25),
        CGPoint(x: center.x + radius, y: center.y),
        CGPoint(x: center.x + radius * 0.25, y: center.y - radius * 0.25),
        CGPoint(x: center.x, y: center.y - radius),
        CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.25),
        CGPoint(x: center.x - radius, y: center.y),
        CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.25)
    ]
    path.move(to: points[0])
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.close()
    path.fill()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "FolicoIconGenerator",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not render PNG for \(url.path)"]
        )
    }

    try png.write(to: url, options: .atomic)
}

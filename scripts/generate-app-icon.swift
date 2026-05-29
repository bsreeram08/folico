import AppKit
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let sourcePath = arguments.first ?? "Assets/AppIcon/FolicoAppIcon.png"
let outputPath = arguments.dropFirst().first ?? "dist/Folico.icns"
let sourceURL = URL(fileURLWithPath: sourcePath)
let outputURL = URL(fileURLWithPath: outputPath)
let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("Folico.iconset", isDirectory: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(
        domain: "FolicoIconGenerator",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not load source icon artwork at \(sourceURL.path)"]
    )
}

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
    let image = resizedImage(sourceImage, size: spec.pixels)
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

func resizedImage(_ source: NSImage, size: CGFloat) -> NSImage {
    let targetSize = NSSize(width: size, height: size)
    let image = NSImage(size: targetSize)
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1
    )

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "FolicoIconGenerator",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not render PNG for \(url.path)"]
        )
    }

    try png.write(to: url, options: .atomic)
}

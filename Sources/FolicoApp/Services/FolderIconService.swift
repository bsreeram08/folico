import AppKit
import Foundation

protocol FolderIconServicing {
    func applyIcon(iconId: String, style: FolderIconStyle?, toFolderAt path: String) throws
    func applyIcon(iconId: String, toFolderAt path: String) throws
    func restoreIcon(forFolderAt path: String) throws
}

extension FolderIconServicing {
    func applyIcon(iconId: String, toFolderAt path: String) throws {
        try applyIcon(iconId: iconId, style: nil, toFolderAt: path)
    }
}

struct FolderIconService: FolderIconServicing {
    func applyIcon(iconId: String, style: FolderIconStyle?, toFolderAt path: String) throws {
        let image = try FolderIconRenderer().render(iconId: iconId, style: style)
        guard NSWorkspace.shared.setIcon(image, forFile: path, options: []) else {
            throw FolderIconError.applyFailed(path)
        }
    }

    func restoreIcon(forFolderAt path: String) throws {
        guard NSWorkspace.shared.setIcon(nil, forFile: path, options: []) else {
            throw FolderIconError.restoreFailed(path)
        }
    }
}

enum FolderIconError: LocalizedError, Equatable {
    case unknownIcon(String)
    case applyFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .unknownIcon(let iconId):
            return "Folico does not know the icon \(iconId)."
        case .applyFailed(let path):
            return "Could not apply the icon to \(path). Check folder permissions."
        case .restoreFailed(let path):
            return "Could not restore the default icon for \(path). Check folder permissions."
        }
    }
}

struct FolderIconRenderer {
    func render(iconId: String, style: FolderIconStyle? = nil, size: CGFloat = 512) throws -> NSImage {
        let descriptor = BuiltInIcons.descriptor(for: iconId)
        guard let symbol = NSImage(systemSymbolName: descriptor.symbolName, accessibilityDescription: descriptor.label) else {
            throw FolderIconError.unknownIcon(iconId)
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let folderColor = color(for: style?.folderColorName, fallback: .controlAccentColor).withAlphaComponent(0.9)
        let shadowColor = NSColor.black.withAlphaComponent(0.16)
        let bodyRect = NSRect(x: size * 0.08, y: size * 0.12, width: size * 0.84, height: size * 0.66)
        let tabRect = NSRect(x: size * 0.13, y: size * 0.70, width: size * 0.31, height: size * 0.16)

        NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: shadowColor.cgColor)
        folderColor.setFill()
        roundedPath(rect: tabRect, radius: size * 0.045).fill()
        roundedPath(rect: bodyRect, radius: size * 0.085).fill()
        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)

        let badgeRect = NSRect(x: size * 0.25, y: size * 0.22, width: size * 0.50, height: size * 0.50)
        NSColor.white.withAlphaComponent(0.88).setFill()
        roundedPath(rect: badgeRect, radius: size * 0.12).fill()

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.28, weight: .semibold)
        let configuredSymbol = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        let symbolRect = NSRect(x: size * 0.33, y: size * 0.31, width: size * 0.34, height: size * 0.34)
        let symbolColor = color(for: style?.symbolColorName ?? descriptor.tintName, fallback: .controlAccentColor)
        tintedImage(configuredSymbol, color: symbolColor, size: symbolRect.size)
            .draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)

        image.isTemplate = false
        return image
    }

    private func roundedPath(rect: NSRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func color(for name: String?, fallback: NSColor) -> NSColor {
        guard let name else { return fallback }
        switch name {
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "gray": return .systemGray
        case "red": return .systemRed
        case "indigo": return .systemIndigo
        case "cyan": return .systemCyan
        case "orange": return .systemOrange
        case "brown": return .systemBrown
        case "mint": return .systemMint
        case "teal": return .systemTeal
        default: return fallback
        }
    }

    private func tintedImage(_ image: NSImage, color: NSColor, size: NSSize) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        defer { output.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.setFill()
        rect.fill(using: .sourceAtop)
        output.isTemplate = false
        return output
    }
}

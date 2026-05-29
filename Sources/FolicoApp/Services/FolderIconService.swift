import AppKit
import Foundation

protocol FolderIconServicing {
    func applyIcon(iconId: String, toFolderAt path: String) throws
    func restoreIcon(forFolderAt path: String) throws
}

struct FolderIconService: FolderIconServicing {
    func applyIcon(iconId: String, toFolderAt path: String) throws {
        let image = try FolderIconRenderer().render(iconId: iconId)
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
    func render(iconId: String, size: CGFloat = 512) throws -> NSImage {
        let descriptor = BuiltInIcons.descriptor(for: iconId)
        guard let symbol = NSImage(systemSymbolName: descriptor.symbolName, accessibilityDescription: descriptor.label) else {
            throw FolderIconError.unknownIcon(iconId)
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let folderColor = NSColor.controlAccentColor.withAlphaComponent(0.9)
        let shadowColor = NSColor.black.withAlphaComponent(0.16)
        let bodyRect = NSRect(x: size * 0.08, y: size * 0.12, width: size * 0.84, height: size * 0.66)
        let tabRect = NSRect(x: size * 0.13, y: size * 0.70, width: size * 0.31, height: size * 0.16)

        NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: shadowColor.cgColor)
        folderColor.setFill()
        roundedPath(rect: tabRect, radius: size * 0.045).fill()
        roundedPath(rect: bodyRect, radius: size * 0.085).fill()
        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)

        let badgeRect = NSRect(x: size * 0.27, y: size * 0.23, width: size * 0.46, height: size * 0.46)
        NSColor.white.withAlphaComponent(0.88).setFill()
        roundedPath(rect: badgeRect, radius: size * 0.12).fill()

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.24, weight: .semibold)
        let configuredSymbol = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        let symbolRect = NSRect(x: size * 0.35, y: size * 0.32, width: size * 0.30, height: size * 0.30)
        tintColor(for: descriptor.tintName).set()
        configuredSymbol.draw(in: symbolRect, from: .zero, operation: .sourceAtop, fraction: 1)

        image.isTemplate = false
        return image
    }

    private func roundedPath(rect: NSRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func tintColor(for name: String) -> NSColor {
        switch name {
        case "green": .systemGreen
        case "blue": .systemBlue
        case "pink": .systemPink
        case "purple": .systemPurple
        case "gray": .systemGray
        case "red": .systemRed
        case "indigo": .systemIndigo
        case "cyan": .systemCyan
        case "orange": .systemOrange
        case "brown": .systemBrown
        case "mint": .systemMint
        default: .controlAccentColor
        }
    }
}

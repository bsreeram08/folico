import Foundation

struct AppConfig: Codable, Equatable {
    var watchedFolders: [WatchedFolder] = []
    var rules: [FolderIconRule] = BuiltInRules.defaultRules
    var overrides: [FolderOverride] = []
    var exclusions: [FolderExclusion] = FolderExclusion.defaultExclusions
    var history: [IconChangeRecord] = []
    var settings: AppSettings = AppSettings()
}

struct AppSettings: Codable, Equatable {
    var excludeHiddenFolders = true
    var enableDeveloperRules = true
    var showMenuBarIcon = false
    var autoWatchFolders = false
}

struct WatchedFolder: Codable, Identifiable, Hashable {
    var id = UUID()
    var path: String
    var bookmarkData: Data?
    var addedAt: Date
    var lastScanAt: Date?
    var lastMatchedCount: Int = 0

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    func securityScopedURL() -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        do {
            return try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            return nil
        }
    }
}

struct FolderIconRule: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var label: String
    var keywords: [String]
    var iconId: String
    var priority: Int
}

struct FolderOverride: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var folderPath: String
    var iconId: String
    var createdAt: Date
}

struct FolderExclusion: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var pattern: String
    var isEnabled: Bool = true

    static let defaultExclusions = [
        FolderExclusion(pattern: ".git"),
        FolderExclusion(pattern: "node_modules"),
        FolderExclusion(pattern: ".next"),
        FolderExclusion(pattern: ".turbo"),
        FolderExclusion(pattern: "Library"),
        FolderExclusion(pattern: "System"),
        FolderExclusion(pattern: "Applications")
    ]
}

struct ScannedFolder: Codable, Identifiable, Equatable, Hashable {
    var id: String { path }
    var path: String
    var name: String
}

struct IconMatchResult: Codable, Equatable, Hashable {
    var folderPath: String
    var folderName: String
    var iconId: String
    var ruleId: String
    var ruleLabel: String
    var confidence: Double
    var source: IconMatchSource
}

enum IconMatchSource: String, Codable, Equatable, Hashable {
    case manualOverride
    case exactKeyword
    case partialKeyword
}

struct FolderPreviewItem: Identifiable, Equatable {
    let id = UUID()
    var rootPath: String
    var folder: ScannedFolder
    var match: IconMatchResult
    var isSelected = true
    var status: FolderPreviewStatus = .ready
}

enum FolderPreviewStatus: Equatable {
    case ready
    case ignored
    case applying
    case applied
    case failed(String)

    var label: String {
        switch self {
        case .ready: "Ready"
        case .ignored: "Ignored"
        case .applying: "Applying"
        case .applied: "Applied"
        case .failed: "Failed"
        }
    }
}

struct IconChangeRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var folderPath: String
    var bookmarkData: Data?
    var previousIconState: PreviousIconState
    var appliedIconId: String
    var appliedAt: Date
    var ruleId: String?
    var status: IconChangeStatus
    var errorMessage: String?

    var folderName: String {
        URL(fileURLWithPath: folderPath).lastPathComponent
    }

    func securityScopedURL() -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        do {
            return try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            return nil
        }
    }
}

enum PreviousIconState: String, Codable, Equatable {
    case `default`
    case custom
    case unknown
}

enum IconChangeStatus: String, Codable, Equatable {
    case applied
    case restored
    case failed
}

struct IconDescriptor: Identifiable, Hashable {
    let id: String
    let label: String
    let symbolName: String
    let tintName: String
}

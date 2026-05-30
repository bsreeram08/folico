import Foundation

struct AppConfig: Codable, Equatable {
    var watchedFolders: [WatchedFolder] = []
    var rules: [FolderIconRule] = BuiltInRules.defaultRules
    var generatedRules: [FolderIconRule]? = BuiltInRules.generatedRules
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
    var notifyOnNewItems = false
    var autoApplyNewFolderIcons = false
    var applyGeneratedIconsToUnmatchedFolders = false
    var learnFromManualChoices = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case excludeHiddenFolders
        case enableDeveloperRules
        case showMenuBarIcon
        case autoWatchFolders
        case notifyOnNewItems
        case autoApplyNewFolderIcons
        case applyGeneratedIconsToUnmatchedFolders
        case learnFromManualChoices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        excludeHiddenFolders = try container.decodeIfPresent(Bool.self, forKey: .excludeHiddenFolders) ?? true
        enableDeveloperRules = try container.decodeIfPresent(Bool.self, forKey: .enableDeveloperRules) ?? true
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? false
        autoWatchFolders = try container.decodeIfPresent(Bool.self, forKey: .autoWatchFolders) ?? false
        notifyOnNewItems = try container.decodeIfPresent(Bool.self, forKey: .notifyOnNewItems) ?? false
        autoApplyNewFolderIcons = try container.decodeIfPresent(Bool.self, forKey: .autoApplyNewFolderIcons) ?? false
        applyGeneratedIconsToUnmatchedFolders = try container.decodeIfPresent(Bool.self, forKey: .applyGeneratedIconsToUnmatchedFolders) ?? false
        learnFromManualChoices = try container.decodeIfPresent(Bool.self, forKey: .learnFromManualChoices) ?? false
    }
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
    var pathKeywords: [String]?
    var iconId: String
    var priority: Int
    var folderColorName: String?
    var symbolColorName: String?
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

    static let defaultPatterns = [
        ".git",
        ".svn",
        ".hg",
        ".build",
        ".cache",
        ".gradle",
        ".idea",
        ".next",
        ".nuxt",
        ".pytest_cache",
        ".ruff_cache",
        ".svelte-kit",
        ".turbo",
        ".venv",
        ".vscode",
        "__pycache__",
        "Applications",
        "build",
        "DerivedData",
        "dist",
        "env",
        "Library",
        "node_modules",
        "Pods",
        "System",
        "target",
        "venv"
    ]

    static let defaultExclusions = defaultPatterns.map { FolderExclusion(pattern: $0) }

    static func defaultsMerged(into exclusions: [FolderExclusion]) -> [FolderExclusion] {
        var merged = exclusions
        var existing = Set(exclusions.map { normalizedPattern($0.pattern) })

        for exclusion in defaultExclusions {
            let normalized = normalizedPattern(exclusion.pattern)
            guard !existing.contains(normalized) else { continue }
            merged.append(exclusion)
            existing.insert(normalized)
        }

        return merged
    }

    static func normalizedPattern(_ pattern: String) -> String {
        pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isDefaultPattern(_ pattern: String) -> Bool {
        let normalized = normalizedPattern(pattern)
        return defaultPatterns.contains { normalizedPattern($0) == normalized }
    }
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
    var style: FolderIconStyle?
}

enum IconMatchSource: String, Codable, Equatable, Hashable {
    case manualOverride
    case exactKeyword
    case partialKeyword
    case pathKeyword
    case generated
}

struct FolderIconStyle: Codable, Equatable, Hashable {
    var folderColorName: String?
    var symbolColorName: String?

    static let availableColorNames = ["blue", "green", "pink", "purple", "gray", "red", "indigo", "cyan", "orange", "brown", "mint", "teal"]

    static func from(rule: FolderIconRule, fallbackSeed: String) -> FolderIconStyle {
        FolderIconStyle(
            folderColorName: rule.folderColorName ?? generatedColorName(for: fallbackSeed),
            symbolColorName: rule.symbolColorName
        )
    }

    static func generated(for seed: String) -> FolderIconStyle {
        FolderIconStyle(
            folderColorName: generatedColorName(for: seed),
            symbolColorName: nil
        )
    }

    private static func generatedColorName(for seed: String) -> String {
        let colors = availableColorNames.filter { $0 != "gray" && $0 != "brown" }
        let hash = seed.unicodeScalars.reduce(5381) { (($0 << 5) &+ $0) &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
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
    case missing
}

struct IconDescriptor: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let symbolName: String
    let tintName: String
}

import Foundation

struct FolicoWorkflow {
    private let scanner: FolderScanner
    private let matcher: FolderRuleMatcher
    private let iconService: FolderIconServicing
    private let storage: AppStorage

    init(
        scanner: FolderScanner = FolderScanner(),
        matcher: FolderRuleMatcher = FolderRuleMatcher(rules: BuiltInRules.defaultRules),
        iconService: FolderIconServicing = FolderIconService(),
        storage: AppStorage = AppStorage()
    ) {
        self.scanner = scanner
        self.matcher = matcher
        self.iconService = iconService
        self.storage = storage
    }

    func scan(path: String, includeHiddenFolders: Bool = false) throws -> FolicoScanReport {
        let config = normalizedConfig(storage.load())
        let result = scanner.scan(
            rootPath: path,
            exclusions: config.exclusions,
            includeHiddenFolders: includeHiddenFolders
        )

        switch result {
        case .success(let folders):
            let suggestions = folders.compactMap { folder -> FolicoSuggestion? in
                guard let match = matcher.match(
                    folder: folder,
                    rules: activeRules(config),
                    overrides: config.overrides,
                    exclusions: config.exclusions
                ) else { return nil }

                return FolicoSuggestion(
                    folderPath: folder.path,
                    folderName: folder.name,
                    iconId: match.iconId,
                    iconLabel: BuiltInIcons.descriptor(for: match.iconId).label,
                    ruleId: match.ruleId,
                    ruleLabel: match.ruleLabel,
                    confidence: match.confidence,
                    matchSource: match.source.rawValue,
                    suggestedName: NamingAdvisor.suggestName(for: folder.name, ruleLabel: match.ruleLabel)
                )
            }
            .sorted { $0.folderName.localizedCaseInsensitiveCompare($1.folderName) == .orderedAscending }

            return FolicoScanReport(
                rootPath: URL(fileURLWithPath: path).standardizedFileURL.path,
                scannedAt: Date(),
                suggestions: suggestions,
                ignoredCount: folders.count - suggestions.count
            )
        case .failure(let error):
            throw error
        }
    }

    func apply(path: String, selectedFolderPaths: Set<String>?, iconOverrides: [String: String] = [:]) throws -> FolicoApplyReport {
        let report = try scan(path: path)
        var config = normalizedConfig(storage.load())
        var results: [FolicoApplyResult] = []

        for suggestion in report.suggestions where selectedFolderPaths == nil || selectedFolderPaths?.contains(suggestion.folderPath) == true {
            let iconId = iconOverrides[suggestion.folderPath] ?? suggestion.iconId
            do {
                try iconService.applyIcon(iconId: iconId, toFolderAt: suggestion.folderPath)
                let record = IconChangeRecord(
                    folderPath: suggestion.folderPath,
                    bookmarkData: nil,
                    previousIconState: .unknown,
                    appliedIconId: iconId,
                    appliedAt: Date(),
                    ruleId: suggestion.ruleId,
                    status: .applied,
                    errorMessage: nil
                )
                config.history.removeAll { $0.folderPath == record.folderPath }
                config.history.insert(record, at: 0)
                results.append(FolicoApplyResult(folderPath: suggestion.folderPath, iconId: iconId, status: "applied", errorMessage: nil))
            } catch {
                results.append(FolicoApplyResult(folderPath: suggestion.folderPath, iconId: iconId, status: "failed", errorMessage: error.localizedDescription))
            }
        }

        try storage.save(config)
        return FolicoApplyReport(rootPath: report.rootPath, appliedAt: Date(), results: results)
    }

    func restore(folderPaths: Set<String>? = nil) throws -> FolicoRestoreReport {
        var config = normalizedConfig(storage.load())
        var results: [FolicoRestoreResult] = []
        let records = config.history.filter { record in
            folderPaths == nil || folderPaths?.contains(record.folderPath) == true
        }

        for record in records {
            do {
                try iconService.restoreIcon(forFolderAt: record.folderPath)
                if let index = config.history.firstIndex(where: { $0.id == record.id }) {
                    config.history[index].status = .restored
                    config.history[index].errorMessage = nil
                }
                results.append(FolicoRestoreResult(folderPath: record.folderPath, status: "restored", errorMessage: nil))
            } catch {
                if let index = config.history.firstIndex(where: { $0.id == record.id }) {
                    config.history[index].status = .failed
                    config.history[index].errorMessage = error.localizedDescription
                }
                results.append(FolicoRestoreResult(folderPath: record.folderPath, status: "failed", errorMessage: error.localizedDescription))
            }
        }

        try storage.save(config)
        return FolicoRestoreReport(restoredAt: Date(), results: results)
    }

    func namingAdvice(path: String) throws -> FolicoNamingReport {
        let report = try scan(path: path)
        return FolicoNamingReport(
            rootPath: report.rootPath,
            generatedAt: Date(),
            suggestions: report.suggestions.map {
                FolicoNamingSuggestion(
                    folderPath: $0.folderPath,
                    currentName: $0.folderName,
                    suggestedName: $0.suggestedName,
                    reason: "Matches \($0.ruleLabel) folders and can use the \($0.iconLabel) icon."
                )
            }
        )
    }

    func reviewNamePlan(proposedNames: [String: String]) -> FolicoNamePlanReview {
        FolicoNamePlanReview(
            reviewedAt: Date(),
            proposals: proposedNames
                .map { folderPath, proposedName in
                    let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let issues = NamingAdvisor.issues(for: trimmed)
                    return FolicoNameProposalReview(
                        folderPath: folderPath,
                        currentName: URL(fileURLWithPath: folderPath).lastPathComponent,
                        proposedName: trimmed,
                        status: issues.isEmpty ? "ok" : "needs_attention",
                        issues: issues
                    )
                }
                .sorted { $0.folderPath.localizedCaseInsensitiveCompare($1.folderPath) == .orderedAscending }
        )
    }

    private func normalizedConfig(_ config: AppConfig) -> AppConfig {
        var config = config
        if config.rules.isEmpty {
            config.rules = BuiltInRules.defaultRules
        }
        if config.exclusions.isEmpty {
            config.exclusions = FolderExclusion.defaultExclusions
        }
        return config
    }

    private func activeRules(_ config: AppConfig) -> [FolderIconRule] {
        config.rules.filter { rule in
            config.settings.enableDeveloperRules || rule.id != "code"
        }
    }
}

struct FolicoScanReport: Codable {
    var rootPath: String
    var scannedAt: Date
    var suggestions: [FolicoSuggestion]
    var ignoredCount: Int
}

struct FolicoSuggestion: Codable {
    var folderPath: String
    var folderName: String
    var iconId: String
    var iconLabel: String
    var ruleId: String
    var ruleLabel: String
    var confidence: Double
    var matchSource: String
    var suggestedName: String
}

struct FolicoApplyReport: Codable {
    var rootPath: String
    var appliedAt: Date
    var results: [FolicoApplyResult]
}

struct FolicoApplyResult: Codable {
    var folderPath: String
    var iconId: String
    var status: String
    var errorMessage: String?
}

struct FolicoRestoreReport: Codable {
    var restoredAt: Date
    var results: [FolicoRestoreResult]
}

struct FolicoRestoreResult: Codable {
    var folderPath: String
    var status: String
    var errorMessage: String?
}

struct FolicoNamingReport: Codable {
    var rootPath: String
    var generatedAt: Date
    var suggestions: [FolicoNamingSuggestion]
}

struct FolicoNamingSuggestion: Codable {
    var folderPath: String
    var currentName: String
    var suggestedName: String
    var reason: String
}

struct FolicoNamePlanReview: Codable {
    var reviewedAt: Date
    var proposals: [FolicoNameProposalReview]
}

struct FolicoNameProposalReview: Codable {
    var folderPath: String
    var currentName: String
    var proposedName: String
    var status: String
    var issues: [String]
}

enum NamingAdvisor {
    static func suggestName(for currentName: String, ruleLabel: String) -> String {
        let trimmed = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ruleLabel }

        let cleaned = trimmed
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")

        return cleaned == trimmed ? trimmed : cleaned
    }

    static func issues(for proposedName: String) -> [String] {
        var issues: [String] = []
        if proposedName.isEmpty {
            issues.append("Name is empty.")
        }
        if proposedName.hasPrefix(".") {
            issues.append("Hidden folder names are skipped by Folico by default.")
        }
        if proposedName.contains("/") || proposedName.contains(":") {
            issues.append("Name contains path separators or reserved characters.")
        }
        if proposedName.count > 80 {
            issues.append("Name is long enough to be hard to scan in Finder.")
        }
        return issues
    }
}

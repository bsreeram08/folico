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
                let explicitMatch = matcher.match(
                    folder: folder,
                    rules: activeRules(config),
                    overrides: config.overrides,
                    exclusions: config.exclusions
                )
                let match = explicitMatch ?? (
                    config.settings.applyGeneratedIconsToUnmatchedFolders
                        ? matcher.generatedMatch(folder: folder, generatedRules: generatedRules(config), exclusions: config.exclusions)
                        : nil
                )
                guard let match else { return nil }

                return FolicoSuggestion(
                    folderPath: folder.path,
                    folderName: folder.name,
                    iconId: match.iconId,
                    iconLabel: BuiltInIcons.descriptor(for: match.iconId).label,
                    ruleId: match.ruleId,
                    ruleLabel: match.ruleLabel,
                    confidence: match.confidence,
                    matchSource: match.source.rawValue,
                    suggestedName: NamingAdvisor.suggestName(for: folder.name, ruleLabel: match.ruleLabel),
                    style: match.style
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
        try apply(plan: planApply(path: path, selectedFolderPaths: selectedFolderPaths, iconOverrides: iconOverrides))
    }

    func planApply(path: String, selectedFolderPaths: Set<String>?, iconOverrides: [String: String] = [:]) throws -> FolicoApplyPlan {
        let report = try scan(path: path)
        let plannedChanges = report.suggestions.compactMap { suggestion -> FolicoPlannedIconChange? in
            guard selectedFolderPaths == nil || selectedFolderPaths?.contains(suggestion.folderPath) == true else {
                return nil
            }
            let iconId = iconOverrides[suggestion.folderPath] ?? suggestion.iconId
            return FolicoPlannedIconChange(
                folderPath: suggestion.folderPath,
                folderName: suggestion.folderName,
                iconId: iconId,
                iconLabel: BuiltInIcons.descriptor(for: iconId).label,
                ruleId: suggestion.ruleId,
                ruleLabel: suggestion.ruleLabel,
                confidence: suggestion.confidence,
                style: suggestion.style
            )
        }

        return FolicoApplyPlan(
            rootPath: report.rootPath,
            generatedAt: Date(),
            plannedChanges: plannedChanges,
            requiresConfirmation: true,
            applyCommand: "folico agent apply --path \(shellQuote(report.rootPath)) --confirm"
        )
    }

    func apply(plan: FolicoApplyPlan) throws -> FolicoApplyReport {
        var config = normalizedConfig(storage.load())
        var results: [FolicoApplyResult] = []

        for change in plan.plannedChanges {
            guard folderExists(at: change.folderPath) else {
                let record = IconChangeRecord(
                    folderPath: change.folderPath,
                    bookmarkData: nil,
                    previousIconState: .unknown,
                    appliedIconId: change.iconId,
                    appliedAt: Date(),
                    ruleId: change.ruleId,
                    status: .missing,
                    errorMessage: nil
                )
                config.history.removeAll { $0.folderPath == record.folderPath }
                config.history.insert(record, at: 0)
                results.append(FolicoApplyResult(folderPath: change.folderPath, iconId: change.iconId, status: "missing", errorMessage: nil))
                continue
            }

            do {
                try iconService.applyIcon(iconId: change.iconId, style: change.style, toFolderAt: change.folderPath)
                let record = IconChangeRecord(
                    folderPath: change.folderPath,
                    bookmarkData: nil,
                    previousIconState: .unknown,
                    appliedIconId: change.iconId,
                    appliedAt: Date(),
                    ruleId: change.ruleId,
                    status: .applied,
                    errorMessage: nil
                )
                config.history.removeAll { $0.folderPath == record.folderPath }
                config.history.insert(record, at: 0)
                results.append(FolicoApplyResult(folderPath: change.folderPath, iconId: change.iconId, status: "applied", errorMessage: nil))
            } catch {
                results.append(FolicoApplyResult(folderPath: change.folderPath, iconId: change.iconId, status: "failed", errorMessage: error.localizedDescription))
            }
        }

        try storage.save(config)
        return FolicoApplyReport(rootPath: plan.rootPath, appliedAt: Date(), results: results)
    }

    func restore(folderPaths: Set<String>? = nil) throws -> FolicoRestoreReport {
        var config = normalizedConfig(storage.load())
        var results: [FolicoRestoreResult] = []
        let records = config.history.filter { record in
            folderPaths == nil || folderPaths?.contains(record.folderPath) == true
        }

        for record in records {
            guard folderExists(at: record.folderPath) else {
                if let index = config.history.firstIndex(where: { $0.id == record.id }) {
                    config.history[index].status = .missing
                    config.history[index].errorMessage = nil
                }
                results.append(FolicoRestoreResult(folderPath: record.folderPath, status: "missing", errorMessage: nil))
                continue
            }

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

    func planRestore(folderPaths: Set<String>? = nil) -> FolicoRestorePlan {
        let config = normalizedConfig(storage.load())
        let records = config.history.filter { record in
            folderPaths == nil || folderPaths?.contains(record.folderPath) == true
        }

        return FolicoRestorePlan(
            generatedAt: Date(),
            plannedRestores: records.map {
                FolicoPlannedRestore(
                    folderPath: $0.folderPath,
                    folderName: $0.folderName,
                    appliedIconId: $0.appliedIconId,
                    status: $0.status.rawValue
                )
            },
            requiresConfirmation: true,
            restoreCommand: "folico agent restore --confirm"
        )
    }

    func settingsReport() -> FolicoSettingsReport {
        let config = normalizedConfig(storage.load())
        return FolicoSettingsReport(
            configPath: storage.fileURL.path,
            settings: config.settings
        )
    }

    func updateSettings(_ patch: FolicoSettingsPatch) throws -> FolicoSettingsReport {
        var config = normalizedConfig(storage.load())
        if let value = patch.autoWatchFolders {
            config.settings.autoWatchFolders = value
        }
        if let value = patch.notifyOnNewItems {
            config.settings.notifyOnNewItems = value
        }
        if let value = patch.autoApplyNewFolderIcons {
            config.settings.autoApplyNewFolderIcons = value
        }
        if let value = patch.applyGeneratedIconsToUnmatchedFolders {
            config.settings.applyGeneratedIconsToUnmatchedFolders = value
        }
        if let value = patch.showMenuBarIcon {
            config.settings.showMenuBarIcon = value
        }
        if let value = patch.learnFromManualChoices {
            config.settings.learnFromManualChoices = value
        }
        try storage.save(config)
        return settingsReport()
    }

    func watchedFoldersReport() -> FolicoWatchedFoldersReport {
        let config = normalizedConfig(storage.load())
        return FolicoWatchedFoldersReport(
            configPath: storage.fileURL.path,
            watchedFolders: config.watchedFolders
        )
    }

    func addWatchedFolder(path: String) throws -> FolicoWatchedFoldersReport {
        var config = normalizedConfig(storage.load())
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !config.watchedFolders.contains(where: { URL(fileURLWithPath: $0.path).standardizedFileURL.path == standardizedPath }) else {
            return watchedFoldersReport()
        }
        config.watchedFolders.append(WatchedFolder(path: standardizedPath, bookmarkData: nil, addedAt: Date()))
        try storage.save(config)
        return watchedFoldersReport()
    }

    func rulesReport() -> FolicoRulesReport {
        let config = normalizedConfig(storage.load())
        return FolicoRulesReport(
            configPath: storage.fileURL.path,
            iconRules: activeRules(config),
            generatedRules: generatedRules(config),
            availableIcons: BuiltInIcons.all,
            availableColors: FolderIconStyle.availableColorNames
        )
    }

    func exclusionsReport() -> FolicoExclusionsReport {
        let config = normalizedConfig(storage.load())
        return FolicoExclusionsReport(
            configPath: storage.fileURL.path,
            exclusions: config.exclusions,
            defaultPatterns: FolderExclusion.defaultPatterns
        )
    }

    func upsertExclusion(pattern: String, isEnabled: Bool = true) throws -> FolicoExclusionsReport {
        var config = normalizedConfig(storage.load())
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exclusionsReport() }

        if let index = config.exclusions.firstIndex(where: {
            FolderExclusion.normalizedPattern($0.pattern) == FolderExclusion.normalizedPattern(trimmed)
        }) {
            config.exclusions[index].isEnabled = isEnabled
        } else {
            config.exclusions.append(FolderExclusion(pattern: trimmed, isEnabled: isEnabled))
            config.exclusions.sort {
                $0.pattern.localizedCaseInsensitiveCompare($1.pattern) == .orderedAscending
            }
        }

        try storage.save(config)
        return exclusionsReport()
    }

    func setExclusion(pattern: String, isEnabled: Bool) throws -> FolicoExclusionsReport {
        var config = normalizedConfig(storage.load())
        let normalized = FolderExclusion.normalizedPattern(pattern)
        if let index = config.exclusions.firstIndex(where: { FolderExclusion.normalizedPattern($0.pattern) == normalized }) {
            config.exclusions[index].isEnabled = isEnabled
            try storage.save(config)
        }
        return exclusionsReport()
    }

    func removeExclusion(pattern: String) throws -> FolicoExclusionsReport {
        var config = normalizedConfig(storage.load())
        let normalized = FolderExclusion.normalizedPattern(pattern)
        if FolderExclusion.isDefaultPattern(pattern),
           let index = config.exclusions.firstIndex(where: { FolderExclusion.normalizedPattern($0.pattern) == normalized }) {
            config.exclusions[index].isEnabled = false
        } else {
            config.exclusions.removeAll { FolderExclusion.normalizedPattern($0.pattern) == normalized }
        }
        try storage.save(config)
        return exclusionsReport()
    }

    func upsertGeneratedRule(_ rule: FolderIconRule) throws -> FolicoRulesReport {
        var config = normalizedConfig(storage.load())
        var rules = generatedRules(config)
        rules.removeAll { $0.id == rule.id }
        rules.append(rule)
        config.generatedRules = rules.sorted {
            if $0.priority == $1.priority { return $0.label < $1.label }
            return $0.priority > $1.priority
        }
        try storage.save(config)
        return rulesReport()
    }

    func upsertIconRule(_ rule: FolderIconRule) throws -> FolicoRulesReport {
        var config = normalizedConfig(storage.load())
        config.rules.removeAll { $0.id == rule.id }
        config.rules.append(rule)
        config.rules = BuiltInRules.mergeDefaultRules(into: config.rules)
        try storage.save(config)
        return rulesReport()
    }

    func removeIconRule(id: String) throws -> FolicoRulesReport {
        var config = normalizedConfig(storage.load())
        if !BuiltInRules.isBuiltInRuleID(id) {
            config.rules.removeAll { $0.id == id }
            try storage.save(config)
        }
        return rulesReport()
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
        config.rules = BuiltInRules.mergeDefaultRules(into: config.rules)
        config.exclusions = FolderExclusion.defaultsMerged(into: config.exclusions)
        config.generatedRules = BuiltInRules.mergeGeneratedRules(into: config.generatedRules ?? [])
        return config
    }

    private func activeRules(_ config: AppConfig) -> [FolderIconRule] {
        config.rules.filter { rule in
            config.settings.enableDeveloperRules || rule.id != "code"
        }
    }

    private func generatedRules(_ config: AppConfig) -> [FolderIconRule] {
        config.generatedRules ?? BuiltInRules.generatedRules
    }

    private func folderExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

private func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
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
    var style: FolderIconStyle?
}

struct FolicoApplyReport: Codable {
    var rootPath: String
    var appliedAt: Date
    var results: [FolicoApplyResult]
}

struct FolicoApplyPlan: Codable {
    var rootPath: String
    var generatedAt: Date
    var plannedChanges: [FolicoPlannedIconChange]
    var requiresConfirmation: Bool
    var applyCommand: String
}

struct FolicoPlannedIconChange: Codable {
    var folderPath: String
    var folderName: String
    var iconId: String
    var iconLabel: String
    var ruleId: String
    var ruleLabel: String
    var confidence: Double
    var style: FolderIconStyle?
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

struct FolicoRestorePlan: Codable {
    var generatedAt: Date
    var plannedRestores: [FolicoPlannedRestore]
    var requiresConfirmation: Bool
    var restoreCommand: String
}

struct FolicoPlannedRestore: Codable {
    var folderPath: String
    var folderName: String
    var appliedIconId: String
    var status: String
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

struct FolicoSettingsReport: Codable {
    var configPath: String
    var settings: AppSettings
}

struct FolicoSettingsPatch: Codable {
    var autoWatchFolders: Bool?
    var notifyOnNewItems: Bool?
    var autoApplyNewFolderIcons: Bool?
    var applyGeneratedIconsToUnmatchedFolders: Bool?
    var showMenuBarIcon: Bool?
    var learnFromManualChoices: Bool?
}

struct FolicoRulesReport: Codable {
    var configPath: String
    var iconRules: [FolderIconRule]
    var generatedRules: [FolderIconRule]
    var availableIcons: [IconDescriptor]
    var availableColors: [String]
}

struct FolicoWatchedFoldersReport: Codable {
    var configPath: String
    var watchedFolders: [WatchedFolder]
}

struct FolicoExclusionsReport: Codable {
    var configPath: String
    var exclusions: [FolderExclusion]
    var defaultPatterns: [String]
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

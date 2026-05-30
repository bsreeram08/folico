import AppKit
import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published private(set) var previewItems: [FolderPreviewItem] = []
    @Published var selectedSection: AppSection = .folders
    @Published var isScanning = false
    @Published var isApplying = false
    @Published var isRestoring = false
    @Published var statusMessage: String?

    let storage: AppStorage
    private let scanner: FolderScanner
    private let matcher: FolderRuleMatcher
    private let iconService: FolderIconServicing
    private let notificationService: FolicoNotificationService
    private var liveUpdateService: FolderLiveUpdateService?
    private var recentLiveEventPaths: [String: Date] = [:]

    public convenience init() {
        self.init(
            storage: AppStorage(),
            scanner: FolderScanner(),
            matcher: FolderRuleMatcher(rules: BuiltInRules.defaultRules),
            iconService: FolderIconService(),
            notificationService: FolicoNotificationService()
        )
    }

    init(
        storage: AppStorage = AppStorage(),
        scanner: FolderScanner = FolderScanner(),
        matcher: FolderRuleMatcher = FolderRuleMatcher(rules: BuiltInRules.defaultRules),
        iconService: FolderIconServicing = FolderIconService(),
        notificationService: FolicoNotificationService = FolicoNotificationService()
    ) {
        self.storage = storage
        self.scanner = scanner
        self.matcher = matcher
        self.iconService = iconService
        self.notificationService = notificationService
        self.config = storage.load()
        self.config.rules = BuiltInRules.mergeDefaultRules(into: self.config.rules)
        self.config.generatedRules = BuiltInRules.mergeGeneratedRules(into: self.config.generatedRules ?? [])
        self.config.exclusions = FolderExclusion.defaultsMerged(into: self.config.exclusions)
        saveConfig()
        self.liveUpdateService = FolderLiveUpdateService { [weak self] events in
            Task { @MainActor in
                self?.handleLiveFileSystemEvents(events)
            }
        }
        syncLiveUpdates()
    }

    var matchedCount: Int {
        previewItems.filter(\.isSelected).count
    }

    func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for Folico to scan"
        panel.message = "Folico scans folder names only. It does not upload data or read file contents."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK else { return }

        var added = 0
        for url in panel.urls {
            guard !config.watchedFolders.contains(where: { $0.path == url.path }) else { continue }
            let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            config.watchedFolders.append(
                WatchedFolder(path: url.path, bookmarkData: bookmark, addedAt: Date())
            )
            added += 1
        }

        saveConfig()
        syncLiveUpdates()
        if config.settings.autoWatchFolders && added > 0 {
            scanNow()
        }
        statusMessage = added == 1 ? "Added 1 watched folder." : "Added \(added) watched folders."
    }

    func removeWatchedFolder(_ folder: WatchedFolder) {
        config.watchedFolders.removeAll { $0.id == folder.id }
        previewItems.removeAll { $0.rootPath == folder.path }
        saveConfig()
        syncLiveUpdates()
    }

    func scanNow() {
        guard !config.watchedFolders.isEmpty else {
            selectedSection = .folders
            statusMessage = "Choose at least one folder before scanning."
            return
        }

        isScanning = true
        statusMessage = nil
        defer { isScanning = false }

        var nextPreview: [FolderPreviewItem] = []
        for root in config.watchedFolders {
            let scopedURL = root.securityScopedURL()
            let access = scopedURL?.startAccessingSecurityScopedResource() ?? false

            let result = scanner.scan(
                rootPath: root.path,
                exclusions: config.exclusions,
                includeHiddenFolders: !config.settings.excludeHiddenFolders
            )

            switch result {
            case .success(let folders):
                var matchedForRoot = 0
                for folder in folders {
                    guard let match = matcher.match(
                        folder: folder,
                        rules: activeRules(),
                        overrides: config.overrides,
                        exclusions: config.exclusions
                    ) else { continue }
                    nextPreview.append(FolderPreviewItem(rootPath: root.path, folder: folder, match: match))
                    matchedForRoot += 1
                }
                if let index = config.watchedFolders.firstIndex(where: { $0.id == root.id }) {
                    config.watchedFolders[index].lastScanAt = Date()
                    config.watchedFolders[index].lastMatchedCount = matchedForRoot
                }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }

            if access {
                scopedURL?.stopAccessingSecurityScopedResource()
            }
        }

        previewItems = nextPreview.sorted { $0.folder.name.localizedCaseInsensitiveCompare($1.folder.name) == .orderedAscending }
        selectedSection = .preview
        saveConfig()
    }

    func setPreviewSelection(_ item: FolderPreviewItem, isSelected: Bool) {
        guard let index = previewItems.firstIndex(where: { $0.id == item.id }) else { return }
        previewItems[index].isSelected = isSelected
        previewItems[index].status = isSelected ? .ready : .ignored
    }

    func ignoreSelectedPreviewItems() {
        for index in previewItems.indices where previewItems[index].isSelected {
            previewItems[index].isSelected = false
            previewItems[index].status = .ignored
        }
    }

    func overrideIcon(for item: FolderPreviewItem, iconId: String) {
        config.overrides.removeAll { $0.folderPath == item.folder.path }
        config.overrides.append(FolderOverride(folderPath: item.folder.path, iconId: iconId, createdAt: Date()))
        let style = FolderIconStyle.generated(for: item.folder.path)

        if let index = previewItems.firstIndex(where: { $0.id == item.id }) {
            let match = IconMatchResult(
                folderPath: item.folder.path,
                folderName: item.folder.name,
                iconId: iconId,
                ruleId: "manual",
                ruleLabel: "Manual",
                confidence: 1.0,
                source: .manualOverride,
                style: style
            )
            previewItems[index].match = match
        }

        if config.settings.learnFromManualChoices {
            let learnedRule = learnedRule(folder: item.folder, iconId: iconId, style: style)
            upsertUserRule(learnedRule, statusVerb: "Learned")
        }

        saveConfig()
    }

    func applySelectedIcons() {
        let selected = previewItems.filter(\.isSelected)
        guard !selected.isEmpty else {
            statusMessage = "Select at least one folder to apply icons."
            return
        }

        isApplying = true
        defer { isApplying = false }

        for item in selected {
            updatePreviewStatus(item.id, status: .applying)
            let bookmark = try? URL(fileURLWithPath: item.folder.path).bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            guard folderExists(at: item.folder.path) else {
                let record = IconChangeRecord(
                    folderPath: item.folder.path,
                    bookmarkData: bookmark,
                    previousIconState: .unknown,
                    appliedIconId: item.match.iconId,
                    appliedAt: Date(),
                    ruleId: item.match.ruleId,
                    status: .missing,
                    errorMessage: nil
                )
                upsertHistory(record)
                updatePreviewStatus(item.id, status: .failed("Folder no longer exists."))
                continue
            }

            do {
                try iconService.applyIcon(iconId: item.match.iconId, style: item.match.style, toFolderAt: item.folder.path)
                let record = IconChangeRecord(
                    folderPath: item.folder.path,
                    bookmarkData: bookmark,
                    previousIconState: .unknown,
                    appliedIconId: item.match.iconId,
                    appliedAt: Date(),
                    ruleId: item.match.ruleId,
                    status: .applied,
                    errorMessage: nil
                )
                upsertHistory(record)
                updatePreviewStatus(item.id, status: .applied)
            } catch {
                let record = IconChangeRecord(
                    folderPath: item.folder.path,
                    bookmarkData: bookmark,
                    previousIconState: .unknown,
                    appliedIconId: item.match.iconId,
                    appliedAt: Date(),
                    ruleId: item.match.ruleId,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
                upsertHistory(record)
                updatePreviewStatus(item.id, status: .failed(error.localizedDescription))
            }
        }

        selectedSection = .history
        saveConfig()
    }

    func restore(_ record: IconChangeRecord) {
        isRestoring = true
        defer { isRestoring = false }

        guard folderExists(at: record.folderPath) else {
            updateHistory(record.id, status: .missing, errorMessage: nil)
            saveConfig()
            statusMessage = "Folder no longer exists: \(record.folderName)."
            return
        }

        let scopedURL = record.securityScopedURL()
        let access = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if access { scopedURL?.stopAccessingSecurityScopedResource() } }

        do {
            try iconService.restoreIcon(forFolderAt: record.folderPath)
            updateHistory(record.id, status: .restored, errorMessage: nil)
        } catch {
            updateHistory(record.id, status: .failed, errorMessage: error.localizedDescription)
        }
        saveConfig()
    }

    func restoreAll() {
        isRestoring = true
        defer { isRestoring = false }

        for record in config.history where record.status == .applied || record.status == .failed {
            guard folderExists(at: record.folderPath) else {
                updateHistory(record.id, status: .missing, errorMessage: nil)
                continue
            }

            let scopedURL = record.securityScopedURL()
            let access = scopedURL?.startAccessingSecurityScopedResource() ?? false

            do {
                try iconService.restoreIcon(forFolderAt: record.folderPath)
                updateHistory(record.id, status: .restored, errorMessage: nil)
            } catch {
                updateHistory(record.id, status: .failed, errorMessage: error.localizedDescription)
            }

            if access {
                scopedURL?.stopAccessingSecurityScopedResource()
            }
        }
        saveConfig()
    }

    func clearMissingHistoryRecords() {
        config.history.removeAll { !folderExists(at: $0.folderPath) || $0.status == .missing }
        saveConfig()
        statusMessage = "Cleared missing history records."
    }

    func openInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func resetSettings() {
        config.settings = AppSettings()
        saveConfig()
        syncLiveUpdates()
    }

    func setExcludeHiddenFolders(_ isEnabled: Bool) {
        config.settings.excludeHiddenFolders = isEnabled
        saveConfig()
    }

    func setEnableDeveloperRules(_ isEnabled: Bool) {
        config.settings.enableDeveloperRules = isEnabled
        saveConfig()
    }

    func setAutoWatchFolders(_ isEnabled: Bool) {
        config.settings.autoWatchFolders = isEnabled
        saveConfig()
        syncLiveUpdates()

        if isEnabled {
            if config.watchedFolders.isEmpty {
                statusMessage = "Live updates are on. Add a watched folder to monitor."
            } else {
                statusMessage = "Live updates are on. Refreshing preview."
                scanNow()
            }
        } else {
            statusMessage = "Live updates are off."
        }
    }

    func setShowMenuBarIcon(_ isShown: Bool) {
        config.settings.showMenuBarIcon = isShown
        saveConfig()
        statusMessage = isShown ? "Menu bar icon is on." : "Menu bar icon is off."
    }

    func setNotifyOnNewItems(_ isEnabled: Bool) {
        config.settings.notifyOnNewItems = isEnabled
        saveConfig()
        if isEnabled {
            notificationService.requestAuthorizationIfNeeded()
        }
        statusMessage = isEnabled ? "Notifications are on." : "Notifications are off."
    }

    func setAutoApplyNewFolderIcons(_ isEnabled: Bool) {
        config.settings.autoApplyNewFolderIcons = isEnabled
        saveConfig()
        statusMessage = isEnabled ? "New folder icon application is on." : "New folder icon application is off."
    }

    func setApplyGeneratedIconsToUnmatchedFolders(_ isEnabled: Bool) {
        config.settings.applyGeneratedIconsToUnmatchedFolders = isEnabled
        saveConfig()
        statusMessage = isEnabled ? "Generated fallback icons are on." : "Generated fallback icons are off."
    }

    func setLearnFromManualChoices(_ isEnabled: Bool) {
        config.settings.learnFromManualChoices = isEnabled
        saveConfig()
        statusMessage = isEnabled ? "Local learning is on." : "Local learning is off."
    }

    var userRules: [FolderIconRule] {
        config.rules
            .filter { !BuiltInRules.isBuiltInRuleID($0.id) }
            .sorted {
                if $0.priority == $1.priority { return $0.label < $1.label }
                return $0.priority > $1.priority
            }
    }

    func addUserRule(
        label: String,
        keywords: [String],
        pathKeywords: [String],
        iconId: String,
        folderColorName: String?,
        symbolColorName: String?
    ) {
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedKeywords = cleanKeywords(keywords)
        let cleanedPathKeywords = cleanKeywords(pathKeywords)
        guard !cleanedLabel.isEmpty, !cleanedKeywords.isEmpty else {
            statusMessage = "Rules need a label and at least one keyword."
            return
        }

        let rule = FolderIconRule(
            id: "user-\(Self.slug(cleanedLabel))",
            label: cleanedLabel,
            keywords: cleanedKeywords,
            pathKeywords: cleanedPathKeywords.isEmpty ? nil : cleanedPathKeywords,
            iconId: iconId,
            priority: 120,
            folderColorName: folderColorName,
            symbolColorName: symbolColorName
        )
        upsertUserRule(rule, statusVerb: "Added")
        saveConfig()
    }

    func removeUserRule(_ rule: FolderIconRule) {
        guard !BuiltInRules.isBuiltInRuleID(rule.id) else { return }
        config.rules.removeAll { $0.id == rule.id }
        saveConfig()
        statusMessage = "Removed rule: \(rule.label)."
    }

    func addExclusion(pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = config.exclusions.firstIndex(where: {
            FolderExclusion.normalizedPattern($0.pattern) == FolderExclusion.normalizedPattern(trimmed)
        }) {
            config.exclusions[index].isEnabled = true
            statusMessage = "Exclusion is on: \(config.exclusions[index].pattern)."
        } else {
            config.exclusions.append(FolderExclusion(pattern: trimmed, isEnabled: true))
            config.exclusions.sort {
                $0.pattern.localizedCaseInsensitiveCompare($1.pattern) == .orderedAscending
            }
            statusMessage = "Added exclusion: \(trimmed)."
        }

        saveConfig()
    }

    func setExclusion(_ exclusion: FolderExclusion, isEnabled: Bool) {
        guard let index = config.exclusions.firstIndex(where: { $0.id == exclusion.id }) else { return }
        config.exclusions[index].isEnabled = isEnabled
        saveConfig()
    }

    func removeExclusion(_ exclusion: FolderExclusion) {
        if FolderExclusion.isDefaultPattern(exclusion.pattern) {
            setExclusion(exclusion, isEnabled: false)
            statusMessage = "Disabled default exclusion: \(exclusion.pattern)."
            return
        }

        config.exclusions.removeAll { $0.id == exclusion.id }
        saveConfig()
        statusMessage = "Removed exclusion: \(exclusion.pattern)."
    }

    private func activeRules() -> [FolderIconRule] {
        config.rules.filter { rule in
            config.settings.enableDeveloperRules || rule.id != "code"
        }
    }

    private func generatedRules() -> [FolderIconRule] {
        config.generatedRules ?? BuiltInRules.generatedRules
    }

    private func syncLiveUpdates() {
        if config.settings.autoWatchFolders {
            liveUpdateService?.update(paths: config.watchedFolders.map(\.path))
            if config.settings.notifyOnNewItems {
                notificationService.requestAuthorizationIfNeeded()
            }
        } else {
            liveUpdateService?.stop()
        }
    }

    private func handleLiveFileSystemEvents(_ events: [LiveFileSystemEvent]) {
        guard config.settings.autoWatchFolders else { return }
        pruneRecentLiveEvents()

        var didChangeConfig = false
        for event in events {
            guard markLiveEventIfNeeded(event.path) else { continue }
            guard let watchedFolder = watchedFolder(containing: event.path) else { continue }
            guard !isExcludedLivePath(event.path) else { continue }

            switch event.kind {
            case .file:
                notifyIfEnabled(
                    title: "New file",
                    body: "\(URL(fileURLWithPath: event.path).lastPathComponent) was created in \(watchedFolder.name)."
                )
            case .folder:
                didChangeConfig = processLiveFolder(event.path, root: watchedFolder) || didChangeConfig
            }
        }

        if didChangeConfig {
            saveConfig()
        }
    }

    private func processLiveFolder(_ path: String, root: WatchedFolder) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        let folder = ScannedFolder(path: path, name: URL(fileURLWithPath: path).lastPathComponent)
        let explicitMatch = matcher.match(
            folder: folder,
            rules: activeRules(),
            overrides: config.overrides,
            exclusions: config.exclusions
        )
        let match = explicitMatch ?? (
            config.settings.applyGeneratedIconsToUnmatchedFolders
                ? matcher.generatedMatch(folder: folder, generatedRules: generatedRules(), exclusions: config.exclusions)
                : nil
        )

        guard let match else {
            notifyIfEnabled(title: "New folder", body: "\(folder.name) was created in \(root.name).")
            return false
        }

        upsertPreviewItem(rootPath: root.path, folder: folder, match: match)
        updateWatchedFolderStats(rootID: root.id)

        guard config.settings.autoApplyNewFolderIcons else {
            notifyIfEnabled(title: "New folder match", body: "\(folder.name) matched \(match.ruleLabel).")
            return true
        }

        let scopedURL = root.securityScopedURL()
        let access = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if access { scopedURL?.stopAccessingSecurityScopedResource() } }

        do {
            try iconService.applyIcon(iconId: match.iconId, style: match.style, toFolderAt: folder.path)
            upsertHistory(
                IconChangeRecord(
                    folderPath: folder.path,
                    bookmarkData: nil,
                    previousIconState: .unknown,
                    appliedIconId: match.iconId,
                    appliedAt: Date(),
                    ruleId: match.ruleId,
                    status: .applied,
                    errorMessage: nil
                )
            )
            updatePreviewStatus(folder.path, status: .applied)
            notifyIfEnabled(title: "Folder icon applied", body: "\(folder.name) now uses \(match.ruleLabel).")
        } catch {
            upsertHistory(
                IconChangeRecord(
                    folderPath: folder.path,
                    bookmarkData: nil,
                    previousIconState: .unknown,
                    appliedIconId: match.iconId,
                    appliedAt: Date(),
                    ruleId: match.ruleId,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
            )
            updatePreviewStatus(folder.path, status: .failed(error.localizedDescription))
            notifyIfEnabled(title: "Folder icon failed", body: "\(folder.name): \(error.localizedDescription)")
        }

        return true
    }

    private func watchedFolder(containing path: String) -> WatchedFolder? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return config.watchedFolders.first { folder in
            let rootPath = URL(fileURLWithPath: folder.path).standardizedFileURL.path
            return standardizedPath == rootPath || standardizedPath.hasPrefix(rootPath + "/")
        }
    }

    private func isExcludedLivePath(_ path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent
        if config.settings.excludeHiddenFolders, name.hasPrefix(".") {
            return true
        }
        return FolderRuleMatcher.isExcluded(name: name, path: path, exclusions: config.exclusions)
    }

    private func notifyIfEnabled(title: String, body: String) {
        guard config.settings.notifyOnNewItems else { return }
        notificationService.notify(title: title, body: body)
    }

    private func pruneRecentLiveEvents() {
        let cutoff = Date().addingTimeInterval(-2)
        recentLiveEventPaths = recentLiveEventPaths.filter { $0.value > cutoff }
    }

    private func markLiveEventIfNeeded(_ path: String) -> Bool {
        if recentLiveEventPaths[path] != nil {
            return false
        }
        recentLiveEventPaths[path] = Date()
        return true
    }

    func folderExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func upsertHistory(_ record: IconChangeRecord) {
        config.history.removeAll { $0.folderPath == record.folderPath }
        config.history.insert(record, at: 0)
    }

    private func updateHistory(_ id: UUID, status: IconChangeStatus, errorMessage: String?) {
        guard let index = config.history.firstIndex(where: { $0.id == id }) else { return }
        config.history[index].status = status
        config.history[index].errorMessage = errorMessage
    }

    private func updatePreviewStatus(_ id: UUID, status: FolderPreviewStatus) {
        guard let index = previewItems.firstIndex(where: { $0.id == id }) else { return }
        previewItems[index].status = status
    }

    private func updatePreviewStatus(_ folderPath: String, status: FolderPreviewStatus) {
        guard let index = previewItems.firstIndex(where: { $0.folder.path == folderPath }) else { return }
        previewItems[index].status = status
    }

    private func upsertPreviewItem(rootPath: String, folder: ScannedFolder, match: IconMatchResult) {
        if let index = previewItems.firstIndex(where: { $0.folder.path == folder.path }) {
            previewItems[index].match = match
            previewItems[index].isSelected = true
            previewItems[index].status = .ready
        } else {
            previewItems.append(FolderPreviewItem(rootPath: rootPath, folder: folder, match: match))
        }
        previewItems.sort { $0.folder.name.localizedCaseInsensitiveCompare($1.folder.name) == .orderedAscending }
    }

    private func updateWatchedFolderStats(rootID: UUID) {
        guard let index = config.watchedFolders.firstIndex(where: { $0.id == rootID }) else { return }
        config.watchedFolders[index].lastScanAt = Date()
        config.watchedFolders[index].lastMatchedCount = previewItems.filter {
            $0.rootPath == config.watchedFolders[index].path
        }.count
    }

    private func saveConfig() {
        do {
            try storage.save(config)
        } catch {
            statusMessage = "Could not save Folico settings: \(error.localizedDescription)"
        }
    }

    private func upsertUserRule(_ rule: FolderIconRule, statusVerb: String) {
        config.rules.removeAll { $0.id == rule.id }
        config.rules.append(rule)
        config.rules = BuiltInRules.mergeDefaultRules(into: config.rules)
        statusMessage = "\(statusVerb) rule: \(rule.label)."
    }

    private func learnedRule(folder: ScannedFolder, iconId: String, style: FolderIconStyle) -> FolderIconRule {
        let keywords = Self.keywords(from: folder.name)
        let label = folder.name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")

        return FolderIconRule(
            id: "learned-\(Self.slug(folder.name))",
            label: label.isEmpty ? "Learned Rule" : label,
            keywords: keywords.isEmpty ? [folder.name] : keywords,
            pathKeywords: nil,
            iconId: iconId,
            priority: 125,
            folderColorName: style.folderColorName,
            symbolColorName: style.symbolColorName
        )
    }

    private func cleanKeywords(_ keywords: [String]) -> [String] {
        Array(Set(keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func keywords(from value: String) -> [String] {
        let normalized = FolderRuleMatcher.normalize(value)
        let words = normalized.split(separator: " ").map(String.init)
        let phrase = normalized.isEmpty ? [] : [normalized]
        return Array(Set(phrase + words)).sorted()
    }

    private static func slug(_ value: String) -> String {
        let normalized = FolderRuleMatcher.normalize(value)
        let slug = normalized.replacingOccurrences(of: " ", with: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case folders
    case preview
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .folders: "Folders"
        case .preview: "Preview"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .folders: "folder"
        case .preview: "eye"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

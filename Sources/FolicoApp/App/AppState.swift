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

    public convenience init() {
        self.init(
            storage: AppStorage(),
            scanner: FolderScanner(),
            matcher: FolderRuleMatcher(rules: BuiltInRules.defaultRules),
            iconService: FolderIconService()
        )
    }

    init(
        storage: AppStorage = AppStorage(),
        scanner: FolderScanner = FolderScanner(),
        matcher: FolderRuleMatcher = FolderRuleMatcher(rules: BuiltInRules.defaultRules),
        iconService: FolderIconServicing = FolderIconService()
    ) {
        self.storage = storage
        self.scanner = scanner
        self.matcher = matcher
        self.iconService = iconService
        self.config = storage.load()
        if self.config.rules.isEmpty {
            self.config.rules = BuiltInRules.defaultRules
        }
        if self.config.exclusions.isEmpty {
            self.config.exclusions = FolderExclusion.defaultExclusions
        }
        saveConfig()
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
        statusMessage = added == 1 ? "Added 1 watched folder." : "Added \(added) watched folders."
    }

    func removeWatchedFolder(_ folder: WatchedFolder) {
        config.watchedFolders.removeAll { $0.id == folder.id }
        previewItems.removeAll { $0.rootPath == folder.path }
        saveConfig()
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

        if let index = previewItems.firstIndex(where: { $0.id == item.id }) {
            let match = IconMatchResult(
                folderPath: item.folder.path,
                folderName: item.folder.name,
                iconId: iconId,
                ruleId: "manual",
                ruleLabel: "Manual",
                confidence: 1.0,
                source: .manualOverride
            )
            previewItems[index].match = match
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

            do {
                try iconService.applyIcon(iconId: item.match.iconId, toFolderAt: item.folder.path)
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

    func openInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func resetSettings() {
        config.settings = AppSettings()
        saveConfig()
    }

    private func activeRules() -> [FolderIconRule] {
        config.rules.filter { rule in
            config.settings.enableDeveloperRules || rule.id != "code"
        }
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

    private func saveConfig() {
        do {
            try storage.save(config)
        } catch {
            statusMessage = "Could not save Folico settings: \(error.localizedDescription)"
        }
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

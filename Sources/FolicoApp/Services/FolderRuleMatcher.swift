import Foundation

struct FolderRuleMatcher {
    private let rules: [FolderIconRule]

    init(rules: [FolderIconRule]) {
        self.rules = rules
    }

    func match(
        folder: ScannedFolder,
        rules overrideRules: [FolderIconRule]? = nil,
        overrides: [FolderOverride],
        exclusions: [FolderExclusion]
    ) -> IconMatchResult? {
        guard !Self.isExcluded(name: folder.name, path: folder.path, exclusions: exclusions) else {
            return nil
        }

        if let override = overrides.first(where: { $0.folderPath == folder.path }) {
            return IconMatchResult(
                folderPath: folder.path,
                folderName: folder.name,
                iconId: override.iconId,
                ruleId: "manual",
                ruleLabel: "Manual",
                confidence: 1.0,
                source: .manualOverride,
                style: .generated(for: folder.path)
            )
        }

        let normalizedName = Self.normalize(folder.name)
        let normalizedPath = URL(fileURLWithPath: folder.path)
            .deletingLastPathComponent()
            .pathComponents
            .map(Self.normalize)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let candidates = (overrideRules ?? rules).sorted {
            if $0.priority == $1.priority { return $0.label < $1.label }
            return $0.priority > $1.priority
        }

        for rule in candidates {
            if rule.keywords.map(Self.normalize).contains(normalizedName) {
                return Self.result(folder: folder, rule: rule, confidence: 1.0, source: .exactKeyword)
            }
        }

        for rule in candidates {
            let normalizedKeywords = rule.keywords.map(Self.normalize)
            if normalizedKeywords.contains(where: { keyword in
                normalizedName.contains(keyword) || keyword.contains(normalizedName)
            }) {
                return Self.result(folder: folder, rule: rule, confidence: 0.72, source: .partialKeyword)
            }
        }

        for rule in candidates {
            let normalizedKeywords = (rule.pathKeywords ?? []).map(Self.normalize)
            if normalizedKeywords.contains(where: { keyword in
                normalizedPath.contains(keyword) || keyword.contains(normalizedName)
            }) {
                return Self.result(folder: folder, rule: rule, confidence: 0.66, source: .pathKeyword)
            }
        }

        return nil
    }

    func generatedMatch(
        folder: ScannedFolder,
        generatedRules: [FolderIconRule],
        exclusions: [FolderExclusion]
    ) -> IconMatchResult? {
        guard !Self.isExcluded(name: folder.name, path: folder.path, exclusions: exclusions) else {
            return nil
        }

        let normalizedName = Self.normalize(folder.name)
        let normalizedPath = URL(fileURLWithPath: folder.path)
            .deletingLastPathComponent()
            .pathComponents
            .map(Self.normalize)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let candidates = generatedRules.sorted {
            if $0.priority == $1.priority { return $0.label < $1.label }
            return $0.priority > $1.priority
        }

        for rule in candidates {
            let normalizedKeywords = rule.keywords.map(Self.normalize)
            if normalizedKeywords.contains(normalizedName) {
                return Self.result(folder: folder, rule: rule, confidence: 0.86, source: .generated)
            }
        }

        for rule in candidates {
            let normalizedKeywords = rule.keywords.map(Self.normalize)
            if normalizedKeywords.contains(where: { keyword in
                normalizedName.contains(keyword) || keyword.contains(normalizedName)
            }) {
                return Self.result(folder: folder, rule: rule, confidence: 0.62, source: .generated)
            }
        }

        for rule in candidates {
            let normalizedKeywords = (rule.pathKeywords ?? []).map(Self.normalize)
            if normalizedKeywords.contains(where: { keyword in
                normalizedPath.contains(keyword) || keyword.contains(normalizedName)
            }) {
                return Self.result(folder: folder, rule: rule, confidence: 0.56, source: .generated)
            }
        }

        return IconMatchResult(
            folderPath: folder.path,
            folderName: folder.name,
            iconId: "folder",
            ruleId: "generated",
            ruleLabel: "Generated",
            confidence: 0.50,
            source: .generated,
            style: .generated(for: folder.path)
        )
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func isExcluded(name: String, path: String, exclusions: [FolderExclusion]) -> Bool {
        let rawName = name.lowercased()
        let pathComponents = URL(fileURLWithPath: path).pathComponents.map { $0.lowercased() }
        let normalizedName = normalize(name)
        return exclusions
            .filter(\.isEnabled)
            .contains { exclusion in
                let rawPattern = exclusion.pattern.lowercased()
                let normalizedPattern = normalize(exclusion.pattern)

                if rawPattern.hasPrefix(".") {
                    return rawName == rawPattern || pathComponents.contains(rawPattern)
                }

                return normalizedName == normalizedPattern || pathComponents.contains(rawPattern)
            }
    }

    private static func result(
        folder: ScannedFolder,
        rule: FolderIconRule,
        confidence: Double,
        source: IconMatchSource
    ) -> IconMatchResult {
        IconMatchResult(
            folderPath: folder.path,
            folderName: folder.name,
            iconId: rule.iconId,
            ruleId: rule.id,
            ruleLabel: rule.label,
            confidence: confidence,
            source: source,
            style: .from(rule: rule, fallbackSeed: folder.path)
        )
    }

}

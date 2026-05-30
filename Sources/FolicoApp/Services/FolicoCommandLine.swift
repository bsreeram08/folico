import Foundation

public enum FolicoCommandLine {
    public static func run(arguments: [String]) -> Int {
        let command = arguments.first ?? "help"
        let rest = Array(arguments.dropFirst())

        do {
            switch command {
            case "agent":
                return try agent(arguments: rest)
            case "scan":
                return try scan(arguments: rest)
            case "apply":
                let options = try CLIOptions(arguments: rest)
                let path = try options.requiredPath()
                let workflow = FolicoWorkflow()
                let selected: Set<String>?
                if let items = options.indexValue("--items") {
                    let scanReport = try workflow.scan(path: path, includeHiddenFolders: options.hasFlag("--include-hidden"))
                    selected = Set(items.compactMap { index in
                        guard scanReport.suggestions.indices.contains(index - 1) else { return nil }
                        return scanReport.suggestions[index - 1].folderPath
                    })
                } else {
                    selected = options.csvValue("--folders").map { Set($0.map { expandPath($0) }) }
                }
                let overrides = options.mappingValue("--icons").reduce(into: [String: String]()) { output, pair in
                    output[expandPath(pair.key)] = pair.value
                }
                let report = try workflow.apply(path: path, selectedFolderPaths: selected, iconOverrides: overrides)
                if options.hasFlag("--json") {
                    print(try JSONPrinter.encode(report))
                } else {
                    printApply(report)
                }
                return report.results.contains(where: { $0.status == "failed" }) ? 2 : 0
            case "restore":
                let options = try CLIOptions(arguments: rest)
                let selected = options.csvValue("--folders").map { Set($0.map { expandPath($0) }) }
                let report = try FolicoWorkflow().restore(folderPaths: selected)
                if options.hasFlag("--json") {
                    print(try JSONPrinter.encode(report))
                } else {
                    printRestore(report)
                }
                return report.results.contains(where: { $0.status == "failed" }) ? 2 : 0
            case "names":
                let options = try CLIOptions(arguments: rest)
                let path = try options.requiredPath()
                let report = try FolicoWorkflow().namingAdvice(path: path)
                if options.hasFlag("--json") {
                    print(try JSONPrinter.encode(report))
                } else {
                    printNames(report)
                }
                return 0
            case "settings":
                print(try JSONPrinter.encode(FolicoWorkflow().settingsReport()))
                return 0
            case "rules":
                print(try JSONPrinter.encode(FolicoWorkflow().rulesReport()))
                return 0
            case "exclusions":
                print(try JSONPrinter.encode(FolicoWorkflow().exclusionsReport()))
                return 0
            case "mcp":
                try FolicoMCPServer().run()
                return 0
            case "help", "--help", "-h":
                printHelp()
                return 0
            default:
                if !command.hasPrefix("-") {
                    return try scan(arguments: arguments)
                } else {
                    fputs("Unknown command: \(command)\n\n", stderr)
                    printHelp()
                    return 64
                }
            }
        } catch {
            fputs("Folico error: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func scan(arguments: [String]) throws -> Int {
        let options = try CLIOptions(arguments: arguments)
        let path = try options.requiredPath()
        let report = try FolicoWorkflow().scan(path: path, includeHiddenFolders: options.hasFlag("--include-hidden"))
        if options.hasFlag("--json") {
            print(try JSONPrinter.encode(report))
        } else {
            printScan(report)
        }
        return 0
    }

    private static func printScan(_ report: FolicoScanReport) {
        print("Folico scan: \(report.rootPath)")
        if report.suggestions.isEmpty {
            print("No matching folder icon suggestions.")
            return
        }

        for (index, suggestion) in report.suggestions.enumerated() {
            print("[\(index + 1)] \(suggestion.folderName) -> \(suggestion.iconLabel) (\(suggestion.ruleLabel), \(Int(suggestion.confidence * 100))%)")
            print("    \(suggestion.folderPath)")
        }
        print("\nApply selected folders:")
        print("folico apply \(shellQuote(report.rootPath)) --items 1,2")
    }

    private static func printApply(_ report: FolicoApplyReport) {
        print("Folico apply: \(report.rootPath)")
        for result in report.results {
            let suffix = result.errorMessage.map { " - \($0)" } ?? ""
            print("\(result.status): \(result.folderPath) -> \(result.iconId)\(suffix)")
        }
    }

    private static func printRestore(_ report: FolicoRestoreReport) {
        print("Folico restore")
        for result in report.results {
            let suffix = result.errorMessage.map { " - \($0)" } ?? ""
            print("\(result.status): \(result.folderPath)\(suffix)")
        }
    }

    private static func printNames(_ report: FolicoNamingReport) {
        print("Folico naming advice: \(report.rootPath)")
        for suggestion in report.suggestions {
            print("\(suggestion.currentName) -> \(suggestion.suggestedName)")
            print("    \(suggestion.reason)")
        }
    }

    private static func printHelp() {
        print("""
        Folico

        Usage:
          folico                         Open the macOS app
          folico <folder>                Scan child folders and preview icon suggestions
          folico agent scan --path <folder>
          folico agent plan --path <folder> [--json]
          folico agent apply --path <folder> [--items 1,3] --confirm
          folico agent restore [--folders path1,path2] --confirm
          folico agent names --path <folder>
          folico agent review-names --names path=name,path=name
          folico scan <folder> [--json]  Scan child folders and preview icon suggestions
          folico apply <folder> [--items 1,3] [--folders path1,path2] [--icons path=iconId] [--json]
          folico restore [--folders path1,path2] [--json]
          folico names <folder> [--json] Suggest safer folder naming
          folico settings                Print local settings JSON
          folico rules                   Print icon rule JSON
          folico exclusions              Print exclusion rule JSON
          folico mcp                     Start the Folico MCP stdio server

        Notes:
          apply changes Finder folder icons; scan and names never modify folders.
          restore clears custom folder icons for Folico history records.
        """)
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func expandPath(_ value: String) -> String {
        NSString(string: value).expandingTildeInPath
    }
}

private extension FolicoCommandLine {
    static func agent(arguments: [String]) throws -> Int {
        let action = arguments.first ?? "help"
        let options = try CLIOptions(arguments: Array(arguments.dropFirst()))
        let workflow = FolicoWorkflow()

        switch action {
        case "scan":
            let path = try options.requiredPathOption()
            print(try JSONPrinter.encode(workflow.scan(path: path, includeHiddenFolders: options.hasFlag("--include-hidden"))))
            return 0
        case "plan":
            let path = try options.requiredPathOption()
            let selected = try selectedFolders(from: options, workflow: workflow, path: path)
            let overrides = expandedMappings(options.mappingValue("--icons"))
            print(try JSONPrinter.encode(workflow.planApply(path: path, selectedFolderPaths: selected, iconOverrides: overrides)))
            return 0
        case "apply":
            guard options.hasFlag("--confirm") else {
                throw CLIError.confirmationRequired("Use folico agent plan first, then pass --confirm to apply selected icons.")
            }
            let path = try options.requiredPathOption()
            let selected = try selectedFolders(from: options, workflow: workflow, path: path)
            let overrides = expandedMappings(options.mappingValue("--icons"))
            let plan = try workflow.planApply(path: path, selectedFolderPaths: selected, iconOverrides: overrides)
            let report = try workflow.apply(plan: plan)
            print(try JSONPrinter.encode(report))
            return report.results.contains(where: { $0.status == "failed" }) ? 2 : 0
        case "restore-plan":
            let selected = options.csvValue("--folders").map { Set($0.map { expandPath($0) }) }
            print(try JSONPrinter.encode(workflow.planRestore(folderPaths: selected)))
            return 0
        case "restore":
            guard options.hasFlag("--confirm") else {
                throw CLIError.confirmationRequired("Use folico agent restore-plan first, then pass --confirm to restore icons.")
            }
            let selected = options.csvValue("--folders").map { Set($0.map { expandPath($0) }) }
            let report = try workflow.restore(folderPaths: selected)
            print(try JSONPrinter.encode(report))
            return report.results.contains(where: { $0.status == "failed" }) ? 2 : 0
        case "names":
            let path = try options.requiredPathOption()
            print(try JSONPrinter.encode(workflow.namingAdvice(path: path)))
            return 0
        case "review-names":
            let proposedNames = expandedMappings(options.mappingValue("--names"))
            print(try JSONPrinter.encode(workflow.reviewNamePlan(proposedNames: proposedNames)))
            return 0
        case "settings":
            print(try JSONPrinter.encode(workflow.settingsReport()))
            return 0
        case "configure-settings":
            print(try JSONPrinter.encode(workflow.updateSettings(FolicoSettingsPatch(
                autoWatchFolders: options.boolValue("--auto-watch"),
                notifyOnNewItems: options.boolValue("--notify"),
                autoApplyNewFolderIcons: options.boolValue("--auto-apply-new-folder-icons"),
                applyGeneratedIconsToUnmatchedFolders: options.boolValue("--generated-fallback"),
                showMenuBarIcon: options.boolValue("--menu-bar"),
                learnFromManualChoices: options.boolValue("--learn")
            ))))
            return 0
        case "watched-folders":
            print(try JSONPrinter.encode(workflow.watchedFoldersReport()))
            return 0
        case "watch-folder":
            let path = try options.requiredPathOption()
            print(try JSONPrinter.encode(workflow.addWatchedFolder(path: path)))
            return 0
        case "rules":
            print(try JSONPrinter.encode(workflow.rulesReport()))
            return 0
        case "upsert-rule":
            let label = try options.requiredValue("--label")
            let rule = try FolderIconRule(
                id: options.value("--id") ?? "user-\(slug(label))",
                label: label,
                keywords: options.csvValue("--keywords") ?? [],
                pathKeywords: options.csvValue("--path-keywords"),
                iconId: options.requiredValue("--icon"),
                priority: options.intValue("--priority") ?? 120,
                folderColorName: options.value("--folder-color"),
                symbolColorName: options.value("--symbol-color") ?? options.value("--folder-color")
            )
            print(try JSONPrinter.encode(workflow.upsertIconRule(rule)))
            return 0
        case "remove-rule":
            print(try JSONPrinter.encode(workflow.removeIconRule(id: options.requiredValue("--id"))))
            return 0
        case "exclusions":
            print(try JSONPrinter.encode(workflow.exclusionsReport()))
            return 0
        case "add-exclusion":
            print(try JSONPrinter.encode(workflow.upsertExclusion(
                pattern: options.requiredValue("--pattern"),
                isEnabled: options.boolValue("--enabled") ?? true
            )))
            return 0
        case "set-exclusion":
            print(try JSONPrinter.encode(workflow.setExclusion(
                pattern: options.requiredValue("--pattern"),
                isEnabled: options.boolValue("--enabled") ?? true
            )))
            return 0
        case "remove-exclusion":
            print(try JSONPrinter.encode(workflow.removeExclusion(pattern: options.requiredValue("--pattern"))))
            return 0
        case "upsert-generated-rule":
            let rule = try FolderIconRule(
                id: options.requiredValue("--id"),
                label: options.requiredValue("--label"),
                keywords: options.csvValue("--keywords") ?? [],
                pathKeywords: options.csvValue("--path-keywords"),
                iconId: options.requiredValue("--icon"),
                priority: options.intValue("--priority") ?? 10,
                folderColorName: options.value("--folder-color"),
                symbolColorName: options.value("--symbol-color")
            )
            print(try JSONPrinter.encode(workflow.upsertGeneratedRule(rule)))
            return 0
        case "help", "--help", "-h":
            printAgentHelp()
            return 0
        default:
            fputs("Unknown agent action: \(action)\n\n", stderr)
            printAgentHelp()
            return 64
        }
    }

    static func selectedFolders(from options: CLIOptions, workflow: FolicoWorkflow, path: String) throws -> Set<String>? {
        if let items = options.indexValue("--items") {
            let scanReport = try workflow.scan(path: path, includeHiddenFolders: options.hasFlag("--include-hidden"))
            return Set(items.compactMap { index in
                guard scanReport.suggestions.indices.contains(index - 1) else { return nil }
                return scanReport.suggestions[index - 1].folderPath
            })
        }
        return options.csvValue("--folders").map { Set($0.map { expandPath($0) }) }
    }

    static func expandedMappings(_ mappings: [String: String]) -> [String: String] {
        mappings.reduce(into: [String: String]()) { output, pair in
            output[expandPath(pair.key)] = pair.value
        }
    }

    static func printAgentHelp() {
        print("""
        Folico agent CLI

        All agent commands print JSON.

        Usage:
          folico agent plan --path <folder> [--items 1,3] [--folders path1,path2] [--icons path=iconId]
          folico agent scan --path <folder>
          folico agent apply --path <folder> [--items 1,3] [--folders path1,path2] [--icons path=iconId] --confirm
          folico agent restore-plan [--folders path1,path2]
          folico agent restore [--folders path1,path2] --confirm
          folico agent names --path <folder>
          folico agent review-names --names path=name,path=name
          folico agent settings
          folico agent configure-settings [--auto-watch true] [--notify true] [--auto-apply-new-folder-icons true] [--generated-fallback true] [--learn true]
          folico agent watched-folders
          folico agent watch-folder --path <folder>
          folico agent rules
          folico agent upsert-rule --label <label> --icon <iconId> --keywords a,b [--path-keywords a,b] [--folder-color blue]
          folico agent remove-rule --id <id>
          folico agent exclusions
          folico agent add-exclusion --pattern <name> [--enabled true]
          folico agent set-exclusion --pattern <name> --enabled false
          folico agent remove-exclusion --pattern <name>
          folico agent upsert-generated-rule --id <id> --label <label> --icon <iconId> [--keywords a,b] [--path-keywords a,b] [--folder-color blue]
        """)
    }

    static func slug(_ value: String) -> String {
        let normalized = FolderRuleMatcher.normalize(value)
        let slug = normalized.replacingOccurrences(of: " ", with: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }
}

struct CLIOptions {
    let positional: [String]
    private let flags: Set<String>
    private let values: [String: String]

    init(arguments: [String]) throws {
        var positional: [String] = []
        var flags = Set<String>()
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument.hasPrefix("--") {
                if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                    values[argument] = arguments[index + 1]
                    index += 2
                } else {
                    flags.insert(argument)
                    index += 1
                }
            } else {
                positional.append(argument)
                index += 1
            }
        }

        self.positional = positional
        self.flags = flags
        self.values = values
    }

    func hasFlag(_ flag: String) -> Bool {
        flags.contains(flag)
    }

    func value(_ key: String) -> String? {
        values[key]
    }

    func requiredValue(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw CLIError.missingOption(key)
        }
        return value
    }

    func requiredPath() throws -> String {
        guard let path = positional.first else {
            throw CLIError.missingPath
        }
        return NSString(string: path).expandingTildeInPath
    }

    func requiredPathOption() throws -> String {
        guard let path = values["--path"] ?? positional.first else {
            throw CLIError.missingPath
        }
        return NSString(string: path).expandingTildeInPath
    }

    func csvValue(_ key: String) -> [String]? {
        values[key]?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func indexValue(_ key: String) -> [Int]? {
        csvValue(key)?.compactMap(Int.init)
    }

    func intValue(_ key: String) -> Int? {
        values[key].flatMap(Int.init)
    }

    func boolValue(_ key: String) -> Bool? {
        guard let value = values[key]?.lowercased() else { return nil }
        switch value {
        case "true", "yes", "1", "on": return true
        case "false", "no", "0", "off": return false
        default: return nil
        }
    }

    func mappingValue(_ key: String) -> [String: String] {
        guard let raw = values[key] else { return [:] }
        return raw
            .split(separator: ",")
            .reduce(into: [String: String]()) { output, pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                output[parts[0]] = parts[1]
            }
    }
}

enum CLIError: LocalizedError {
    case missingPath
    case missingOption(String)
    case confirmationRequired(String)

    var errorDescription: String? {
        switch self {
        case .missingPath:
            return "Missing folder path."
        case .missingOption(let option):
            return "Missing required option \(option)."
        case .confirmationRequired(let message):
            return message
        }
    }
}

enum JSONPrinter {
    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(data: try encoder.encode(value), encoding: .utf8) ?? "{}"
    }
}

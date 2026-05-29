import Foundation

public enum FolicoCommandLine {
    public static func run(arguments: [String]) -> Int {
        let command = arguments.first ?? "help"
        let rest = Array(arguments.dropFirst())

        do {
            switch command {
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
          folico scan <folder> [--json]  Scan child folders and preview icon suggestions
          folico apply <folder> [--items 1,3] [--folders path1,path2] [--icons path=iconId] [--json]
          folico restore [--folders path1,path2] [--json]
          folico names <folder> [--json] Suggest safer folder naming
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

    func requiredPath() throws -> String {
        guard let path = positional.first else {
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

    var errorDescription: String? {
        switch self {
        case .missingPath:
            return "Missing folder path."
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

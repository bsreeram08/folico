import Foundation

struct FolicoMCPServer {
    private let workflow = FolicoWorkflow()

    func run() throws {
        while let message = MCPTransport.readMessage() {
            guard let data = message.data(using: .utf8) else { continue }
            let request = try JSONDecoder().decode(MCPRequest.self, from: data)

            if request.method.hasPrefix("notifications/") {
                continue
            }

            let response = handle(request)
            try MCPTransport.write(response)
        }
    }

    private func handle(_ request: MCPRequest) -> MCPResponse {
        do {
            switch request.method {
            case "initialize":
                return .success(id: request.id, result: [
                    "protocolVersion": .string("2024-11-05"),
                    "capabilities": .object(["tools": .object([:])]),
                    "serverInfo": .object([
                        "name": .string("folico"),
                        "version": .string("0.1.0")
                    ])
                ])
            case "ping":
                return .success(id: request.id, result: [:])
            case "tools/list":
                return .success(id: request.id, result: ["tools": .array(toolDefinitions)])
            case "tools/call":
                return try callTool(request)
            default:
                return .failure(id: request.id, code: -32601, message: "Unknown MCP method: \(request.method)")
            }
        } catch {
            return .failure(id: request.id, code: -32000, message: error.localizedDescription)
        }
    }

    private func callTool(_ request: MCPRequest) throws -> MCPResponse {
        guard case .object(let params) = request.params ?? .object([:]),
              case .string(let name) = params["name"] else {
            return .failure(id: request.id, code: -32602, message: "tools/call requires a tool name.")
        }

        let arguments: [String: MCPValue]
        if case .object(let object) = params["arguments"] {
            arguments = object
        } else {
            arguments = [:]
        }

        let payload: String
        switch name {
        case "folico_scan_folder":
            let path = try requiredString("path", in: arguments)
            let includeHidden = bool("includeHiddenFolders", in: arguments) ?? false
            payload = try JSONPrinter.encode(workflow.scan(path: path, includeHiddenFolders: includeHidden))
        case "folico_apply_icons":
            guard bool("confirmApply", in: arguments) == true else {
                throw MCPToolError.confirmationRequired("Set confirmApply to true after reviewing folico_scan_folder output.")
            }
            let path = try requiredString("path", in: arguments)
            let folderPaths = stringArray("folderPaths", in: arguments).map(Set.init)
            let overrides = stringMap("iconOverrides", in: arguments)
            payload = try JSONPrinter.encode(workflow.apply(path: path, selectedFolderPaths: folderPaths, iconOverrides: overrides))
        case "folico_restore_icons":
            guard bool("confirmRestore", in: arguments) == true else {
                throw MCPToolError.confirmationRequired("Set confirmRestore to true after choosing records to restore.")
            }
            let folderPaths = stringArray("folderPaths", in: arguments).map(Set.init)
            payload = try JSONPrinter.encode(workflow.restore(folderPaths: folderPaths))
        case "folico_suggest_folder_names":
            let path = try requiredString("path", in: arguments)
            payload = try JSONPrinter.encode(workflow.namingAdvice(path: path))
        case "folico_review_folder_name_plan":
            let proposedNames = stringMap("proposedNames", in: arguments)
            payload = try JSONPrinter.encode(workflow.reviewNamePlan(proposedNames: proposedNames))
        case "folico_get_settings":
            payload = try JSONPrinter.encode(workflow.settingsReport())
        case "folico_update_settings":
            payload = try JSONPrinter.encode(workflow.updateSettings(FolicoSettingsPatch(
                autoWatchFolders: bool("autoWatchFolders", in: arguments),
                notifyOnNewItems: bool("notifyOnNewItems", in: arguments),
                autoApplyNewFolderIcons: bool("autoApplyNewFolderIcons", in: arguments),
                applyGeneratedIconsToUnmatchedFolders: bool("applyGeneratedIconsToUnmatchedFolders", in: arguments),
                showMenuBarIcon: bool("showMenuBarIcon", in: arguments),
                learnFromManualChoices: bool("learnFromManualChoices", in: arguments)
            )))
        case "folico_list_rules":
            payload = try JSONPrinter.encode(workflow.rulesReport())
        case "folico_upsert_rule":
            let label = try requiredRawString("label", in: arguments)
            let rule = FolderIconRule(
                id: optionalString("id", in: arguments) ?? "user-\(slug(label))",
                label: label,
                keywords: stringArray("keywords", in: arguments) ?? [],
                pathKeywords: stringArray("pathKeywords", in: arguments),
                iconId: try requiredRawString("iconId", in: arguments),
                priority: int("priority", in: arguments) ?? 120,
                folderColorName: optionalString("folderColorName", in: arguments),
                symbolColorName: optionalString("symbolColorName", in: arguments) ?? optionalString("folderColorName", in: arguments)
            )
            payload = try JSONPrinter.encode(workflow.upsertIconRule(rule))
        case "folico_remove_rule":
            payload = try JSONPrinter.encode(workflow.removeIconRule(id: try requiredRawString("id", in: arguments)))
        case "folico_list_exclusions":
            payload = try JSONPrinter.encode(workflow.exclusionsReport())
        case "folico_upsert_exclusion":
            payload = try JSONPrinter.encode(workflow.upsertExclusion(
                pattern: try requiredRawString("pattern", in: arguments),
                isEnabled: bool("isEnabled", in: arguments) ?? true
            ))
        case "folico_set_exclusion_enabled":
            payload = try JSONPrinter.encode(workflow.setExclusion(
                pattern: try requiredRawString("pattern", in: arguments),
                isEnabled: bool("isEnabled", in: arguments) ?? true
            ))
        case "folico_remove_exclusion":
            payload = try JSONPrinter.encode(workflow.removeExclusion(
                pattern: try requiredRawString("pattern", in: arguments)
            ))
        case "folico_list_watched_folders":
            payload = try JSONPrinter.encode(workflow.watchedFoldersReport())
        case "folico_add_watched_folder":
            let path = try requiredString("path", in: arguments)
            payload = try JSONPrinter.encode(workflow.addWatchedFolder(path: path))
        case "folico_upsert_generated_rule":
            let rule = FolderIconRule(
                id: try requiredRawString("id", in: arguments),
                label: try requiredRawString("label", in: arguments),
                keywords: stringArray("keywords", in: arguments) ?? [],
                pathKeywords: stringArray("pathKeywords", in: arguments),
                iconId: try requiredRawString("iconId", in: arguments),
                priority: int("priority", in: arguments) ?? 10,
                folderColorName: optionalString("folderColorName", in: arguments),
                symbolColorName: optionalString("symbolColorName", in: arguments)
            )
            payload = try JSONPrinter.encode(workflow.upsertGeneratedRule(rule))
        default:
            return .failure(id: request.id, code: -32602, message: "Unknown tool: \(name)")
        }

        return .success(id: request.id, result: [
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(payload)
                ])
            ])
        ])
    }

    private var toolDefinitions: [MCPValue] {
        [
            tool(
                name: "folico_scan_folder",
                description: "Scan direct child folders and return Folico icon suggestions without modifying anything.",
                properties: [
                    "path": stringSchema("Root folder to scan."),
                    "includeHiddenFolders": boolSchema("Include hidden child folders.")
                ],
                required: ["path"]
            ),
            tool(
                name: "folico_apply_icons",
                description: "Apply suggested or overridden icons to selected folders. Requires confirmApply=true.",
                properties: [
                    "path": stringSchema("Root folder previously scanned."),
                    "folderPaths": arraySchema("Specific folder paths to apply. Omit to apply all suggestions."),
                    "iconOverrides": objectSchema("Map of folder path to built-in icon id."),
                    "confirmApply": boolSchema("Must be true to modify folder icons.")
                ],
                required: ["path", "confirmApply"]
            ),
            tool(
                name: "folico_restore_icons",
                description: "Restore default folder icons for Folico history records. Requires confirmRestore=true.",
                properties: [
                    "folderPaths": arraySchema("Specific folder paths to restore. Omit to restore all history records."),
                    "confirmRestore": boolSchema("Must be true to clear custom folder icons.")
                ],
                required: ["confirmRestore"]
            ),
            tool(
                name: "folico_suggest_folder_names",
                description: "Suggest clearer folder names based on Folico's icon rules. This does not rename anything.",
                properties: [
                    "path": stringSchema("Root folder to scan for naming advice.")
                ],
                required: ["path"]
            ),
            tool(
                name: "folico_review_folder_name_plan",
                description: "Accept an agent-proposed path-to-name plan and validate it. This does not rename anything.",
                properties: [
                    "proposedNames": objectSchema("Map of folder path to proposed folder name.")
                ],
                required: ["proposedNames"]
            ),
            tool(
                name: "folico_get_settings",
                description: "Return Folico's local settings. Folico does not collect analytics or upload folder data.",
                properties: [:],
                required: []
            ),
            tool(
                name: "folico_update_settings",
                description: "Update Folico's local toggle settings.",
                properties: [
                    "autoWatchFolders": boolSchema("Watch selected folders for newly created files and folders."),
                    "notifyOnNewItems": boolSchema("Show local macOS notifications for new files and folders."),
                    "autoApplyNewFolderIcons": boolSchema("Apply matching icons to newly created folders."),
                    "applyGeneratedIconsToUnmatchedFolders": boolSchema("Generate fallback icons for folders that do not match explicit rules."),
                    "showMenuBarIcon": boolSchema("Show Folico in the macOS menu bar."),
                    "learnFromManualChoices": boolSchema("Create local rules from manual icon choices.")
                ],
                required: []
            ),
            tool(
                name: "folico_list_rules",
                description: "Return explicit icon rules, generated fallback rules, available icons, and color names.",
                properties: [:],
                required: []
            ),
            tool(
                name: "folico_upsert_rule",
                description: "Create or update an explicit local icon rule.",
                properties: [
                    "id": stringSchema("Optional stable rule id. Omit to derive one from label."),
                    "label": stringSchema("User-facing rule label."),
                    "keywords": arraySchema("Folder-name keywords."),
                    "pathKeywords": arraySchema("Parent-path keywords."),
                    "iconId": stringSchema("Built-in icon id from folico_list_rules."),
                    "priority": intSchema("Higher priority rules win. User rules should usually be 120 or higher."),
                    "folderColorName": stringSchema("Folder color name from folico_list_rules."),
                    "symbolColorName": stringSchema("Optional symbol color name from folico_list_rules.")
                ],
                required: ["label", "iconId"]
            ),
            tool(
                name: "folico_remove_rule",
                description: "Remove a user-created icon rule. Built-in rules are retained.",
                properties: [
                    "id": stringSchema("Rule id to remove.")
                ],
                required: ["id"]
            ),
            tool(
                name: "folico_list_exclusions",
                description: "Return local exclusion patterns. Folico skips enabled exclusions while scanning and live-watching.",
                properties: [:],
                required: []
            ),
            tool(
                name: "folico_upsert_exclusion",
                description: "Create or re-enable a local exclusion pattern.",
                properties: [
                    "pattern": stringSchema("Folder name or path component to skip, such as node_modules or DerivedData."),
                    "isEnabled": boolSchema("Whether this exclusion should be active.")
                ],
                required: ["pattern"]
            ),
            tool(
                name: "folico_set_exclusion_enabled",
                description: "Enable or disable an existing local exclusion pattern.",
                properties: [
                    "pattern": stringSchema("Exclusion pattern to update."),
                    "isEnabled": boolSchema("Whether this exclusion should be active.")
                ],
                required: ["pattern", "isEnabled"]
            ),
            tool(
                name: "folico_remove_exclusion",
                description: "Remove a custom exclusion pattern. Built-in defaults are disabled instead of deleted.",
                properties: [
                    "pattern": stringSchema("Exclusion pattern to remove or disable.")
                ],
                required: ["pattern"]
            ),
            tool(
                name: "folico_list_watched_folders",
                description: "Return locally watched folders.",
                properties: [:],
                required: []
            ),
            tool(
                name: "folico_add_watched_folder",
                description: "Add a local folder to Folico's watched-folder list.",
                properties: [
                    "path": stringSchema("Folder path to watch.")
                ],
                required: ["path"]
            ),
            tool(
                name: "folico_upsert_generated_rule",
                description: "Create or update a config-driven generated icon rule.",
                properties: [
                    "id": stringSchema("Stable generated rule id."),
                    "label": stringSchema("User-facing rule label."),
                    "keywords": arraySchema("Folder-name keywords."),
                    "pathKeywords": arraySchema("Parent-path keywords."),
                    "iconId": stringSchema("Built-in icon id from folico_list_rules."),
                    "priority": intSchema("Higher priority rules win."),
                    "folderColorName": stringSchema("Folder color name from folico_list_rules."),
                    "symbolColorName": stringSchema("Optional symbol color name from folico_list_rules.")
                ],
                required: ["id", "label", "iconId"]
            )
        ]
    }

    private func tool(name: String, description: String, properties: [String: MCPValue], required: [String]) -> MCPValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(properties),
                "required": .array(required.map(MCPValue.string))
            ])
        ])
    }

    private func stringSchema(_ description: String) -> MCPValue {
        .object(["type": .string("string"), "description": .string(description)])
    }

    private func boolSchema(_ description: String) -> MCPValue {
        .object(["type": .string("boolean"), "description": .string(description)])
    }

    private func intSchema(_ description: String) -> MCPValue {
        .object(["type": .string("integer"), "description": .string(description)])
    }

    private func arraySchema(_ description: String) -> MCPValue {
        .object([
            "type": .string("array"),
            "description": .string(description),
            "items": .object(["type": .string("string")])
        ])
    }

    private func objectSchema(_ description: String) -> MCPValue {
        .object([
            "type": .string("object"),
            "description": .string(description),
            "additionalProperties": .object(["type": .string("string")])
        ])
    }

    private func requiredString(_ key: String, in arguments: [String: MCPValue]) throws -> String {
        guard case .string(let value) = arguments[key], !value.isEmpty else {
            throw MCPToolError.missingArgument(key)
        }
        return NSString(string: value).expandingTildeInPath
    }

    private func requiredRawString(_ key: String, in arguments: [String: MCPValue]) throws -> String {
        guard case .string(let value) = arguments[key], !value.isEmpty else {
            throw MCPToolError.missingArgument(key)
        }
        return value
    }

    private func optionalString(_ key: String, in arguments: [String: MCPValue]) -> String? {
        if case .string(let value) = arguments[key], !value.isEmpty { return value }
        return nil
    }

    private func bool(_ key: String, in arguments: [String: MCPValue]) -> Bool? {
        if case .bool(let value) = arguments[key] { return value }
        return nil
    }

    private func int(_ key: String, in arguments: [String: MCPValue]) -> Int? {
        if case .int(let value) = arguments[key] { return value }
        return nil
    }

    private func stringArray(_ key: String, in arguments: [String: MCPValue]) -> [String]? {
        guard case .array(let values) = arguments[key] else { return nil }
        return values.compactMap {
            if case .string(let value) = $0 { return value }
            return nil
        }
    }

    private func stringMap(_ key: String, in arguments: [String: MCPValue]) -> [String: String] {
        guard case .object(let object) = arguments[key] else { return [:] }
        return object.reduce(into: [String: String]()) { output, pair in
            if case .string(let value) = pair.value {
                output[pair.key] = value
            }
        }
    }

    private func slug(_ value: String) -> String {
        let normalized = FolderRuleMatcher.normalize(value)
        let slug = normalized.replacingOccurrences(of: " ", with: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }
}

enum MCPTransport {
    static func readMessage() -> String? {
        var contentLength: Int?

        while let line = readLine(strippingNewline: true) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                break
            }

            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }

        guard let contentLength else { return nil }
        let data = FileHandle.standardInput.readData(ofLength: contentLength)
        guard data.count == contentLength else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ response: MCPResponse) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        FileHandle.standardOutput.write(Data("Content-Length: \(data.count)\r\n\r\n".utf8))
        FileHandle.standardOutput.write(data)
    }
}

struct MCPRequest: Decodable {
    var jsonrpc: String?
    var id: MCPValue?
    var method: String
    var params: MCPValue?
}

struct MCPResponse: Encodable {
    var jsonrpc = "2.0"
    var id: MCPValue?
    var result: MCPValue?
    var error: MCPError?

    static func success(id: MCPValue?, result: [String: MCPValue]) -> MCPResponse {
        MCPResponse(id: id, result: .object(result), error: nil)
    }

    static func failure(id: MCPValue?, code: Int, message: String) -> MCPResponse {
        MCPResponse(id: id, result: nil, error: MCPError(code: code, message: message))
    }
}

struct MCPError: Encodable {
    var code: Int
    var message: String
}

indirect enum MCPValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: MCPValue])
    case array([MCPValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: MCPValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([MCPValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported MCP value.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

enum MCPToolError: LocalizedError {
    case missingArgument(String)
    case confirmationRequired(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let key):
            return "Missing MCP tool argument: \(key)."
        case .confirmationRequired(let message):
            return message
        }
    }
}

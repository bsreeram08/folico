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

    private func bool(_ key: String, in arguments: [String: MCPValue]) -> Bool? {
        if case .bool(let value) = arguments[key] { return value }
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

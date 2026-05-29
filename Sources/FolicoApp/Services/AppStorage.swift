import Foundation

struct AppStorage {
    let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultConfigURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> AppConfig {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return AppConfig()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            return AppConfig()
        }
    }

    func save(_ config: AppConfig) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultConfigURL(fileManager: FileManager = .default) -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appending(path: "Folico").appending(path: "config.json")
    }
}

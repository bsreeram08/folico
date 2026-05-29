import Foundation

struct FolderScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(
        rootPath: String,
        exclusions: [FolderExclusion],
        includeHiddenFolders: Bool = false
    ) -> Result<[ScannedFolder], FolderScannerError> {
        guard !isProtectedSystemPath(rootPath) else {
            return .failure(.protectedPath(rootPath))
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failure(.notDirectory(rootPath))
        }

        do {
            let rootURL = URL(fileURLWithPath: rootPath)
            let urls = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: []
            )

            let folders = try urls.compactMap { url -> ScannedFolder? in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                guard values.isDirectory == true else { return nil }
                let name = url.lastPathComponent
                if !includeHiddenFolders, name.hasPrefix(".") || values.isHidden == true {
                    return nil
                }
                if FolderRuleMatcher.isExcluded(name: name, path: url.path, exclusions: exclusions) {
                    return nil
                }
                return ScannedFolder(path: url.path, name: name)
            }

            return .success(folders)
        } catch {
            return .failure(.unreadable(rootPath, error.localizedDescription))
        }
    }

    private func isProtectedSystemPath(_ path: String) -> Bool {
        let protectedPaths = ["/", "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/private"]
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        return protectedPaths.contains(standardized)
    }
}

enum FolderScannerError: LocalizedError, Equatable {
    case notDirectory(String)
    case protectedPath(String)
    case unreadable(String, String)

    var errorDescription: String? {
        switch self {
        case .notDirectory(let path):
            return "\(path) is not a folder."
        case .protectedPath(let path):
            return "\(path) is protected. Choose a folder inside your home directory instead."
        case .unreadable(let path, let message):
            return "Could not scan \(path): \(message)"
        }
    }
}

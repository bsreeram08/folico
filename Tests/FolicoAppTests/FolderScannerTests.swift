import Foundation
import XCTest
@testable import FolicoApp

final class FolderScannerTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appending(path: "FolicoScannerTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDownWithError() throws {
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }

    func testScannerReturnsRegularChildFoldersOnly() throws {
        try makeDirectory("Invoices")
        try makeDirectory("Photos")
        try "not a folder".write(to: rootURL.appending(path: "notes.txt"), atomically: true, encoding: .utf8)

        let result = FolderScanner().scan(rootPath: rootURL.path, exclusions: [])

        let folders = try XCTUnwrap(result.successValue)
        XCTAssertEqual(Set(folders.map(\.name)), ["Invoices", "Photos"])
    }

    func testScannerIgnoresHiddenFoldersByDefault() throws {
        try makeDirectory(".git")
        try makeDirectory("Design")

        let result = FolderScanner().scan(rootPath: rootURL.path, exclusions: [])

        let folders = try XCTUnwrap(result.successValue)
        XCTAssertEqual(folders.map(\.name), ["Design"])
    }

    func testScannerAppliesDefaultExclusions() throws {
        try makeDirectory("node_modules")
        try makeDirectory("Projects")

        let result = FolderScanner().scan(rootPath: rootURL.path, exclusions: FolderExclusion.defaultExclusions)

        let folders = try XCTUnwrap(result.successValue)
        XCTAssertEqual(folders.map(\.name), ["Projects"])
    }

    private func makeDirectory(_ name: String) throws {
        try FileManager.default.createDirectory(at: rootURL.appending(path: name), withIntermediateDirectories: true, attributes: nil)
    }
}

private extension Result where Failure == FolderScannerError {
    var successValue: Success? {
        if case .success(let value) = self { value } else { nil }
    }
}

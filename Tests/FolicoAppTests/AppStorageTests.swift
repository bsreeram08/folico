import Foundation
import XCTest
@testable import FolicoApp

final class AppStorageTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appending(path: "FolicoStorageTests")
            .appending(path: UUID().uuidString)
            .appending(path: "config.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testSaveAndLoadConfig() throws {
        let storage = AppStorage(fileURL: fileURL)
        let watched = WatchedFolder(path: "/Users/test/Documents", bookmarkData: nil, addedAt: Date(timeIntervalSince1970: 100))
        var config = AppConfig()
        config.watchedFolders = [watched]

        try storage.save(config)
        let loaded = storage.load()

        XCTAssertEqual(loaded.watchedFolders.map(\.path), ["/Users/test/Documents"])
    }

    func testHistoryAppendPersists() throws {
        let storage = AppStorage(fileURL: fileURL)
        let record = IconChangeRecord(
            folderPath: "/Users/test/Documents/Invoices",
            bookmarkData: nil,
            previousIconState: .unknown,
            appliedIconId: "receipt",
            appliedAt: Date(timeIntervalSince1970: 200),
            ruleId: "finance",
            status: .applied,
            errorMessage: nil
        )
        var config = AppConfig()
        config.history = [record]

        try storage.save(config)
        let loaded = storage.load()

        XCTAssertEqual(loaded.history.first?.folderPath, record.folderPath)
        XCTAssertEqual(loaded.history.first?.status, .applied)
    }

    func testRestoreStatusPersists() throws {
        let storage = AppStorage(fileURL: fileURL)
        var record = IconChangeRecord(
            folderPath: "/Users/test/Documents/Invoices",
            bookmarkData: nil,
            previousIconState: .unknown,
            appliedIconId: "receipt",
            appliedAt: Date(timeIntervalSince1970: 300),
            ruleId: "finance",
            status: .applied,
            errorMessage: nil
        )
        record.status = .restored
        var config = AppConfig()
        config.history = [record]

        try storage.save(config)
        let loaded = storage.load()

        XCTAssertEqual(loaded.history.first?.status, .restored)
    }
}

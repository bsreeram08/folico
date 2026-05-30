import XCTest
@testable import FolicoApp

final class FolderRuleMatcherTests: XCTestCase {
    private let matcher = FolderRuleMatcher(rules: BuiltInRules.defaultRules)

    func testExactKeywordMatch() {
        let folder = ScannedFolder(path: "/Users/test/Documents/Invoices", name: "Invoices")

        let result = matcher.match(folder: folder, overrides: [], exclusions: [])

        XCTAssertEqual(result?.ruleId, "finance")
        XCTAssertEqual(result?.iconId, "receipt")
        XCTAssertEqual(result?.source, .exactKeyword)
    }

    func testPartialKeywordMatch() {
        let folder = ScannedFolder(path: "/Users/test/Documents/Q4 Investor Decks", name: "Q4 Investor Decks")

        let result = matcher.match(folder: folder, overrides: [], exclusions: [])

        XCTAssertEqual(result?.ruleId, "presentations")
        XCTAssertEqual(result?.iconId, "presentation")
        XCTAssertEqual(result?.source, .partialKeyword)
    }

    func testPriorityOrderingChoosesHighestPriorityRule() {
        let rules = [
            FolderIconRule(id: "low", label: "Low", keywords: ["projects"], iconId: "document", priority: 1),
            FolderIconRule(id: "high", label: "High", keywords: ["projects"], iconId: "code", priority: 99)
        ]
        let folder = ScannedFolder(path: "/Users/test/Projects", name: "Projects")

        let result = matcher.match(folder: folder, rules: rules, overrides: [], exclusions: [])

        XCTAssertEqual(result?.ruleId, "high")
        XCTAssertEqual(result?.iconId, "code")
    }

    func testGamesBeatArchiveForOldGames() {
        let folder = ScannedFolder(path: "/Users/test/Desktop/old_games", name: "old_games")

        let result = matcher.match(folder: folder, overrides: [], exclusions: [])

        XCTAssertEqual(result?.ruleId, "games")
        XCTAssertEqual(result?.iconId, "game")
    }

    func testManualOverrideTakesPrecedence() {
        let folder = ScannedFolder(path: "/Users/test/Documents/Invoices", name: "Invoices")
        let override = FolderOverride(folderPath: folder.path, iconId: "music", createdAt: Date())

        let result = matcher.match(folder: folder, overrides: [override], exclusions: [])

        XCTAssertEqual(result?.ruleId, "manual")
        XCTAssertEqual(result?.iconId, "music")
        XCTAssertEqual(result?.source, .manualOverride)
    }

    func testExclusionTakesPrecedenceOverOverride() {
        let folder = ScannedFolder(path: "/Users/test/project/node_modules", name: "node_modules")
        let override = FolderOverride(folderPath: folder.path, iconId: "code", createdAt: Date())

        let result = matcher.match(folder: folder, overrides: [override], exclusions: FolderExclusion.defaultExclusions)

        XCTAssertNil(result)
    }

    func testDotGitExclusionDoesNotMatchDigital() {
        let folder = ScannedFolder(path: "/Users/test/Documents/Digital Assets", name: "Digital Assets")

        let isExcluded = FolderRuleMatcher.isExcluded(
            name: folder.name,
            path: folder.path,
            exclusions: FolderExclusion.defaultExclusions
        )

        XCTAssertFalse(isExcluded)
    }

    func testNoMatchReturnsNil() {
        let folder = ScannedFolder(path: "/Users/test/Misc", name: "Misc")

        let result = matcher.match(folder: folder, overrides: [], exclusions: [])

        XCTAssertNil(result)
    }
}

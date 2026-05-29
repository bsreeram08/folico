import XCTest
@testable import FolicoApp

final class CommandLineOptionTests: XCTestCase {
    func testParsesIndexedSelection() throws {
        let options = try CLIOptions(arguments: ["~/Documents", "--items", "1,3"])

        XCTAssertEqual(options.indexValue("--items"), [1, 3])
    }

    func testParsesIconOverrideMap() throws {
        let options = try CLIOptions(arguments: ["~/Documents", "--icons", "/tmp/Invoices=receipt,/tmp/Photos=image"])

        XCTAssertEqual(options.mappingValue("--icons")["/tmp/Invoices"], "receipt")
        XCTAssertEqual(options.mappingValue("--icons")["/tmp/Photos"], "image")
    }

    func testNamingAdvisorNormalizesSeparators() {
        XCTAssertEqual(NamingAdvisor.suggestName(for: "client_invoices", ruleLabel: "Finance"), "Client Invoices")
        XCTAssertEqual(NamingAdvisor.suggestName(for: "Design", ruleLabel: "Design"), "Design")
    }

    func testNamingAdvisorFlagsUnsafeNames() {
        XCTAssertTrue(NamingAdvisor.issues(for: "Invoices").isEmpty)
        XCTAssertFalse(NamingAdvisor.issues(for: ".Invoices").isEmpty)
        XCTAssertFalse(NamingAdvisor.issues(for: "Client/Invoices").isEmpty)
    }
}

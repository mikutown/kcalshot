import XCTest
@testable import kcalshot

final class AppVersionTests: XCTestCase {
    func testDisplayStringFormatsVersionAndBuildFromSuppliedBundle() {
        let bundle = Bundle(for: AppVersionTests.self)

        XCTAssertEqual(AppVersion.displayString(from: bundle), "1.0 (1)")
    }
}

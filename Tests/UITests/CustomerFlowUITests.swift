import XCTest
final class CustomerFlowUITests: XCTestCase {
    func testConnectDoesNotCollectBusinessCredentials() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10)); app.buttons["login"].tap()
        XCTAssertEqual(app.textFields.count, 0); XCTAssertEqual(app.secureTextFields.count, 0)
        XCTAssertTrue(app.buttons["logout"].waitForExistence(timeout:10))
    }
    func testCallEndDisconnectAndReconnectFromExistingApplicationSession() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10)); app.buttons["login"].tap()
        let logout = app.buttons["logout"]; XCTAssertTrue(logout.waitForExistence(timeout:10))
        let support = app.buttons["callSupport"]
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:support)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:10),.completed); support.tap()
        let end = app.buttons["endCall"]; XCTAssertTrue(end.waitForExistence(timeout:10)); end.tap()
        XCTAssertTrue(logout.waitForExistence(timeout:10)); XCTAssertFalse(end.exists)
        app.buttons["rebuildHome"].tap(); logout.tap()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10)); app.buttons["login"].tap()
        XCTAssertTrue(logout.waitForExistence(timeout:10)); XCTAssertEqual(app.secureTextFields.count,0)
    }
    func testExpiredApplicationSessionRequestsApplicationLoginWithoutForm() {
        let app=XCUIApplication(); app.launchArguments=["--host-session-expired"]; app.launch()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10)); app.buttons["login"].tap()
        let error=app.staticTexts["homeError"]; XCTAssertTrue(error.waitForExistence(timeout:10))
        XCTAssertEqual(error.label,"Đăng nhập ứng dụng doanh nghiệp trước khi kết nối Voice.")
        XCTAssertEqual(app.textFields.count,0); XCTAssertEqual(app.secureTextFields.count,0)
        XCTAssertFalse(app.buttons["callSupport"].isEnabled)
    }
}

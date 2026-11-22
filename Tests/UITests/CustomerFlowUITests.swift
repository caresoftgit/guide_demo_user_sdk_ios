import XCTest
final class CustomerFlowUITests: XCTestCase {
    func testLoginCallEndReturnsHomeAndLogoutAllowsLoginAgain() {
        let app = XCUIApplication(); app.launch()
        let login = app.buttons["login"]; XCTAssertTrue(login.waitForExistence(timeout:10)); login.tap()
        app.textFields["enterpriseUsername"].tap(); app.textFields["enterpriseUsername"].typeText("123")
        app.secureTextFields["enterprisePassword"].tap(); app.secureTextFields["enterprisePassword"].typeText("fixture-token")
        app.buttons["submitLogin"].tap()
        let logout = app.buttons["logout"]; XCTAssertTrue(logout.waitForExistence(timeout:10))
        let support = app.buttons["callSupport"]; XCTAssertTrue(support.isEnabled); support.tap()
        let end = app.buttons["endCall"]; XCTAssertTrue(end.waitForExistence(timeout:10))
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = "Active customer call"; attachment.lifetime = .keepAlways; add(attachment)
        end.tap(); XCTAssertTrue(support.waitForExistence(timeout:10)); XCTAssertFalse(end.exists)
        logout.tap(); XCTAssertTrue(login.waitForExistence(timeout:10)); login.tap()
        XCTAssertTrue(app.textFields["enterpriseUsername"].waitForExistence(timeout:5))
        XCTAssertEqual(app.secureTextFields["enterprisePassword"].value as? String,"Mật khẩu doanh nghiệp")
    }
    func testRebuiltHomeRetainsEnterpriseSessionForLogout() {
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10));app.buttons["login"].tap()
        app.textFields["enterpriseUsername"].tap();app.textFields["enterpriseUsername"].typeText("customer")
        app.secureTextFields["enterprisePassword"].tap();app.secureTextFields["enterprisePassword"].typeText("password")
        app.buttons["submitLogin"].tap();XCTAssertTrue(app.buttons["logout"].waitForExistence(timeout:10))
        app.buttons["rebuildHome"].tap();app.buttons["logout"].tap()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout:10))
        XCTAssertEqual(app.staticTexts["hostRevocations"].label,"Host revocations: 1")
    }

}

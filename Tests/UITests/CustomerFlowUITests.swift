import XCTest
final class CustomerFlowUITests: XCTestCase {
    func testLoginCallEndReturnsHomeAndLogoutAllowsLoginAgain() {
        let app = XCUIApplication(); app.launch()
        let login = app.buttons["login"]; XCTAssertTrue(login.waitForExistence(timeout:10)); login.tap()
        app.textFields["userID"].tap(); app.textFields["userID"].typeText("123")
        app.secureTextFields["apiToken"].tap(); app.secureTextFields["apiToken"].typeText("fixture-token")
        app.buttons["submitLogin"].tap()
        let logout = app.buttons["logout"]; XCTAssertTrue(logout.waitForExistence(timeout:10))
        let support = app.buttons["callSupport"]; XCTAssertTrue(support.isEnabled); support.tap()
        let end = app.buttons["endCall"]; XCTAssertTrue(end.waitForExistence(timeout:10))
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = "Active customer call"; attachment.lifetime = .keepAlways; add(attachment)
        end.tap(); XCTAssertTrue(support.waitForExistence(timeout:10)); XCTAssertFalse(end.exists)
        logout.tap(); XCTAssertTrue(login.waitForExistence(timeout:10)); login.tap()
        XCTAssertTrue(app.textFields["userID"].waitForExistence(timeout:5))
        XCTAssertEqual(app.secureTextFields["apiToken"].value as? String,"API token của account")
    }
}

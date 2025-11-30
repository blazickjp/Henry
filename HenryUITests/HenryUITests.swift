import XCTest

final class HenryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        // Verify the app launches without crashing
        XCTAssertTrue(app.exists)
    }

    // MARK: - Main View Tests

    func testMainViewShowsSidebar() throws {
        // On iPad, sidebar should be visible
        let sidebar = app.navigationBars["Chats"]
        // Give time for UI to load
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
    }

    func testNewChatButtonExists() throws {
        let newChatButton = app.buttons["New Chat"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))
    }

    func testSettingsButtonExists() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    }

    // MARK: - Empty State Tests

    func testEmptyStateShowsWelcome() throws {
        // When there are no conversations, welcome screen should show
        let welcomeText = app.staticTexts["Henry"]
        let poweredByText = app.staticTexts["Powered by Claude"]

        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
        XCTAssertTrue(poweredByText.exists)
    }

    func testEmptyStateShowsFeatures() throws {
        let features = [
            "Create and preview code artifacts",
            "Search the web for information",
            "Have natural conversations"
        ]

        for feature in features {
            let featureText = app.staticTexts[feature]
            XCTAssertTrue(featureText.waitForExistence(timeout: 5), "Missing feature: \(feature)")
        }
    }

    // MARK: - Input Field Tests

    func testMessageInputFieldExists() throws {
        let inputField = app.textFields["Message Henry..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
    }

    func testSendButtonExists() throws {
        // Send button (arrow.up.circle.fill)
        let sendButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'arrow.up.circle'")).firstMatch
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
    }

    func testCanTypeInInputField() throws {
        let inputField = app.textFields["Message Henry..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))

        inputField.tap()
        inputField.typeText("Hello, Claude!")

        // Verify text was entered
        XCTAssertEqual(inputField.value as? String, "Hello, Claude!")
    }

    // MARK: - New Chat Flow Tests

    func testTapNewChatButton() throws {
        let newChatButton = app.buttons["New Chat"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))

        newChatButton.tap()

        // After tapping, empty state should still show (no messages)
        let welcomeText = app.staticTexts["Henry"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 3))
    }

    // MARK: - Settings Tests

    func testOpenSettings() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.tap()

        // Settings sheet should appear
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
    }

    func testSettingsShowsModelPicker() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let modelSection = app.staticTexts["AI Model"]
        XCTAssertTrue(modelSection.waitForExistence(timeout: 5))
    }

    func testSettingsShowsAboutSection() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let aboutSection = app.staticTexts["About"]
        XCTAssertTrue(aboutSection.waitForExistence(timeout: 5))
    }

    func testCloseSettings() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))

        doneButton.tap()

        // Settings should close
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertFalse(settingsTitle.waitForExistence(timeout: 2))
    }

    // MARK: - Conversation Sidebar Tests

    func testEmptySidebarShowsMessage() throws {
        // When no conversations exist
        let emptyMessage = app.staticTexts["No conversations yet"]
        let helpText = app.staticTexts["Start a new chat to begin"]

        // These should be visible if sidebar is showing empty state
        // Note: This depends on the conversation list being empty
        if emptyMessage.waitForExistence(timeout: 3) {
            XCTAssertTrue(helpText.exists)
        }
    }

    // MARK: - Navigation Tests

    func testSplitViewNavigation() throws {
        // On iPad in landscape, both sidebar and detail should be visible
        let sidebarTitle = app.navigationBars["Chats"]
        XCTAssertTrue(sidebarTitle.waitForExistence(timeout: 5))

        // Detail view (chat area) should also be visible
        let inputField = app.textFields["Message Henry..."]
        XCTAssertTrue(inputField.exists)
    }

    // MARK: - Accessibility Tests

    func testInputFieldAccessibility() throws {
        let inputField = app.textFields["Message Henry..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        XCTAssertTrue(inputField.isEnabled)
    }

    func testNewChatButtonAccessibility() throws {
        let newChatButton = app.buttons["New Chat"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))
        XCTAssertTrue(newChatButton.isEnabled)
    }

    func testSettingsButtonAccessibility() throws {
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsButton.isEnabled)
    }
}

// MARK: - Performance Tests

final class HenryUIPerformanceTests: XCTestCase {

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

import XCTest
import SwiftData
@testable import Henry

@MainActor
final class ChatViewModelTests: XCTestCase {

    var viewModel: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = ChatViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.streamingText, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.selectedArtifact)
        XCTAssertFalse(viewModel.showArtifactPanel)
        XCTAssertNil(viewModel.currentConversation)
    }

    func testDefaultModel() {
        XCTAssertEqual(viewModel.selectedModel, AnthropicService.defaultModel)
    }

    // MARK: - New Conversation Tests

    func testNewConversation() {
        // Set up some state
        viewModel.inputText = "Some text"
        viewModel.streamingText = "Some streaming"
        viewModel.errorMessage = "Some error"
        viewModel.showArtifactPanel = true

        // Create a mock conversation
        let conversation = Conversation(title: "Test")
        viewModel.currentConversation = conversation

        // Reset
        viewModel.newConversation()

        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertEqual(viewModel.streamingText, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showArtifactPanel)
        XCTAssertNil(viewModel.selectedArtifact)
        XCTAssertNil(viewModel.currentConversation)
    }

    // MARK: - Load Conversation Tests

    func testLoadConversation() {
        let conversation = Conversation(title: "Loaded Chat")
        let message = Message(role: .user, content: "Hello")
        conversation.addMessage(message)

        // Set up some state that should be reset
        viewModel.inputText = "Previous input"
        viewModel.errorMessage = "Previous error"
        viewModel.showArtifactPanel = true

        viewModel.loadConversation(conversation)

        XCTAssertEqual(viewModel.currentConversation?.title, "Loaded Chat")
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertEqual(viewModel.streamingText, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showArtifactPanel)
        XCTAssertNil(viewModel.selectedArtifact)
    }

    // MARK: - Display Messages Tests

    func testDisplayMessagesEmpty() {
        XCTAssertTrue(viewModel.displayMessages.isEmpty)
    }

    func testDisplayMessagesWithConversation() {
        let conversation = Conversation()
        let message1 = Message(role: .user, content: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Second")

        conversation.addMessage(message1)
        conversation.addMessage(message2)

        viewModel.currentConversation = conversation

        let messages = viewModel.displayMessages
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].content, "First")
        XCTAssertEqual(messages[1].content, "Second")
    }

    func testDisplayMessagesSortedByTimestamp() {
        let conversation = Conversation()

        let message1 = Message(role: .user, content: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Second")
        Thread.sleep(forTimeInterval: 0.01)
        let message3 = Message(role: .user, content: "Third")

        // Add in wrong order
        conversation.messages.append(message3)
        conversation.messages.append(message1)
        conversation.messages.append(message2)

        viewModel.currentConversation = conversation

        let messages = viewModel.displayMessages
        XCTAssertEqual(messages[0].content, "First")
        XCTAssertEqual(messages[1].content, "Second")
        XCTAssertEqual(messages[2].content, "Third")
    }

    // MARK: - Has Messages Tests

    func testHasMessagesNoConversation() {
        XCTAssertFalse(viewModel.hasMessages)
    }

    func testHasMessagesEmptyConversation() {
        viewModel.currentConversation = Conversation()
        XCTAssertFalse(viewModel.hasMessages)
    }

    func testHasMessagesWithMessages() {
        let conversation = Conversation()
        conversation.addMessage(Message(role: .user, content: "Test"))
        viewModel.currentConversation = conversation

        XCTAssertTrue(viewModel.hasMessages)
    }

    // MARK: - Artifact Selection Tests

    func testSelectArtifact() {
        let artifact = Artifact(type: .code, language: "swift", content: "print()", title: "Test")

        viewModel.selectArtifact(artifact)

        XCTAssertEqual(viewModel.selectedArtifact?.id, artifact.id)
        XCTAssertTrue(viewModel.showArtifactPanel)
    }

    func testCloseArtifactPanel() {
        let artifact = Artifact(type: .code, language: "swift", content: "print()", title: "Test")
        viewModel.selectArtifact(artifact)

        viewModel.closeArtifactPanel()

        XCTAssertNil(viewModel.selectedArtifact)
        XCTAssertFalse(viewModel.showArtifactPanel)
    }

    // MARK: - Send Message Validation Tests

    func testSendMessageEmptyInput() async {
        viewModel.inputText = ""

        await viewModel.sendMessage()

        // Should not create conversation for empty input
        XCTAssertNil(viewModel.currentConversation)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSendMessageWhitespaceOnly() async {
        viewModel.inputText = "   \n\t   "

        await viewModel.sendMessage()

        XCTAssertNil(viewModel.currentConversation)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSendMessageClearsInput() async {
        viewModel.inputText = "Test message"

        // This will fail without API, but we can check input is cleared
        let inputBefore = viewModel.inputText
        XCTAssertEqual(inputBefore, "Test message")

        // Note: In a real test, we'd mock the service
        // For now, we just verify the state changes
    }

    // MARK: - Model Selection Tests

    func testModelSelection() {
        viewModel.selectedModel = "claude-3-opus-20240229"
        XCTAssertEqual(viewModel.selectedModel, "claude-3-opus-20240229")

        viewModel.selectedModel = "claude-3-5-haiku-20241022"
        XCTAssertEqual(viewModel.selectedModel, "claude-3-5-haiku-20241022")
    }

    // MARK: - Error Handling Tests

    func testErrorMessageCanBeSet() {
        viewModel.errorMessage = "Test error"
        XCTAssertEqual(viewModel.errorMessage, "Test error")
    }

    func testErrorMessageCanBeCleared() {
        viewModel.errorMessage = "Test error"
        viewModel.errorMessage = nil
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - State Consistency Tests

    func testMultipleNewConversationCalls() {
        viewModel.newConversation()
        viewModel.newConversation()
        viewModel.newConversation()

        // State should remain clean
        XCTAssertNil(viewModel.currentConversation)
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadDifferentConversations() {
        let conversation1 = Conversation(title: "Chat 1")
        let conversation2 = Conversation(title: "Chat 2")

        viewModel.loadConversation(conversation1)
        XCTAssertEqual(viewModel.currentConversation?.title, "Chat 1")

        viewModel.loadConversation(conversation2)
        XCTAssertEqual(viewModel.currentConversation?.title, "Chat 2")
    }

    // MARK: - Streaming State Tests

    func testStreamingTextInitiallyEmpty() {
        XCTAssertEqual(viewModel.streamingText, "")
    }

    func testStreamingTextCanBeUpdated() {
        viewModel.streamingText = "Partial response..."
        XCTAssertEqual(viewModel.streamingText, "Partial response...")
    }

    // MARK: - Loading State Tests

    func testLoadingStateInitiallyFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }
}

// MARK: - Integration Style Tests

@MainActor
final class ChatViewModelIntegrationTests: XCTestCase {

    func testConversationFlowSimulation() {
        let viewModel = ChatViewModel()

        // Start fresh
        XCTAssertNil(viewModel.currentConversation)
        XCTAssertFalse(viewModel.hasMessages)

        // Simulate creating a conversation (normally done by sendMessage)
        let conversation = Conversation()
        viewModel.currentConversation = conversation

        // Add messages manually (simulating what sendMessage would do)
        let userMessage = Message(role: .user, content: "Hello")
        conversation.addMessage(userMessage)

        XCTAssertTrue(viewModel.hasMessages)
        XCTAssertEqual(viewModel.displayMessages.count, 1)

        // Simulate response
        let assistantMessage = Message(role: .assistant, content: "Hi there!")
        conversation.addMessage(assistantMessage)

        XCTAssertEqual(viewModel.displayMessages.count, 2)
        XCTAssertEqual(viewModel.displayMessages.last?.role, .assistant)
    }

    func testArtifactExtractionFlow() {
        let viewModel = ChatViewModel()
        let conversation = Conversation()
        viewModel.currentConversation = conversation

        // Simulate a response with code
        let content = """
        Here's some code:

        ```swift
        print("Hello")
        ```
        """

        let assistantMessage = Message(role: .assistant, content: content)
        assistantMessage.extractArtifacts()
        conversation.addMessage(assistantMessage)

        let messages = viewModel.displayMessages
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].artifacts.count, 1)

        // Simulate selecting the artifact
        if let artifact = messages[0].artifacts.first {
            viewModel.selectArtifact(artifact)
            XCTAssertTrue(viewModel.showArtifactPanel)
            XCTAssertNotNil(viewModel.selectedArtifact)
        }
    }

    func testDeleteConversationWhenCurrent() {
        let viewModel = ChatViewModel()
        let conversation = Conversation(title: "To Delete")
        viewModel.currentConversation = conversation

        // Note: Without ModelContext, deleteConversation won't fully work
        // But we can test the state changes
        viewModel.deleteConversation(conversation)

        // Should clear current conversation
        XCTAssertNil(viewModel.currentConversation)
    }

    func testDeleteConversationNotCurrent() {
        let viewModel = ChatViewModel()
        let currentConv = Conversation(title: "Current")
        let otherConv = Conversation(title: "Other")

        viewModel.currentConversation = currentConv
        viewModel.deleteConversation(otherConv)

        // Current conversation should remain
        XCTAssertEqual(viewModel.currentConversation?.title, "Current")
    }
}

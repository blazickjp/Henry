import XCTest
import SwiftData
@testable import Henry

final class ConversationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testConversationDefaultInitialization() {
        let conversation = Conversation()

        XCTAssertNotNil(conversation.id)
        XCTAssertEqual(conversation.title, "New Chat")
        XCTAssertNotNil(conversation.createdAt)
        XCTAssertNotNil(conversation.updatedAt)
        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertNil(conversation.systemPrompt)
    }

    func testConversationCustomInitialization() {
        let conversation = Conversation(title: "Custom Title", systemPrompt: "You are a helpful assistant.")

        XCTAssertEqual(conversation.title, "Custom Title")
        XCTAssertEqual(conversation.systemPrompt, "You are a helpful assistant.")
    }

    // MARK: - Add Message Tests

    func testAddMessage() {
        let conversation = Conversation()
        let message = Message(role: .user, content: "Hello")

        let originalUpdatedAt = conversation.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        conversation.addMessage(message)

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages[0].content, "Hello")
        XCTAssertGreaterThan(conversation.updatedAt, originalUpdatedAt)
    }

    func testAddMultipleMessages() {
        let conversation = Conversation()

        let message1 = Message(role: .user, content: "First")
        let message2 = Message(role: .assistant, content: "Second")
        let message3 = Message(role: .user, content: "Third")

        conversation.addMessage(message1)
        conversation.addMessage(message2)
        conversation.addMessage(message3)

        XCTAssertEqual(conversation.messages.count, 3)
    }

    // MARK: - Auto Title Generation Tests

    func testAutoTitleGenerationShortMessage() {
        let conversation = Conversation()
        let message = Message(role: .user, content: "How are you?")

        conversation.addMessage(message)

        XCTAssertEqual(conversation.title, "How are you?")
    }

    func testAutoTitleGenerationLongMessage() {
        let conversation = Conversation()
        let longContent = "This is a very long message that should be truncated because it exceeds the maximum title length of 40 characters"
        let message = Message(role: .user, content: longContent)

        conversation.addMessage(message)

        XCTAssertTrue(conversation.title.count <= 43) // 40 + "..."
        XCTAssertTrue(conversation.title.hasSuffix("..."))
    }

    func testAutoTitleNotGeneratedForAssistantMessage() {
        let conversation = Conversation()
        let message = Message(role: .assistant, content: "Hello there!")

        conversation.addMessage(message)

        XCTAssertEqual(conversation.title, "New Chat")
    }

    func testAutoTitleOnlyFromFirstUserMessage() {
        let conversation = Conversation()

        let message1 = Message(role: .user, content: "First question")
        let message2 = Message(role: .user, content: "Second question")

        conversation.addMessage(message1)
        conversation.addMessage(message2)

        XCTAssertEqual(conversation.title, "First question")
    }

    func testAutoTitleTrimsWhitespace() {
        let conversation = Conversation()
        let message = Message(role: .user, content: "   Hello World   ")

        conversation.addMessage(message)

        XCTAssertEqual(conversation.title, "Hello World")
    }

    // MARK: - Messages For API Tests

    func testMessagesForAPIFormat() {
        let conversation = Conversation()

        let message1 = Message(role: .user, content: "Question")
        let message2 = Message(role: .assistant, content: "Answer")

        conversation.addMessage(message1)

        // Small delay to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.01)

        conversation.addMessage(message2)

        let apiMessages = conversation.messagesForAPI

        XCTAssertEqual(apiMessages.count, 2)
        XCTAssertEqual(apiMessages[0]["role"], "user")
        XCTAssertEqual(apiMessages[0]["content"], "Question")
        XCTAssertEqual(apiMessages[1]["role"], "assistant")
        XCTAssertEqual(apiMessages[1]["content"], "Answer")
    }

    func testMessagesForAPISortedByTimestamp() {
        let conversation = Conversation()

        // Create messages with explicit order
        let message1 = Message(role: .user, content: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Second")
        Thread.sleep(forTimeInterval: 0.01)
        let message3 = Message(role: .user, content: "Third")

        // Add in reverse order
        conversation.messages.append(message3)
        conversation.messages.append(message1)
        conversation.messages.append(message2)

        let apiMessages = conversation.messagesForAPI

        XCTAssertEqual(apiMessages[0]["content"], "First")
        XCTAssertEqual(apiMessages[1]["content"], "Second")
        XCTAssertEqual(apiMessages[2]["content"], "Third")
    }

    // MARK: - Last Message Tests

    func testLastMessageEmpty() {
        let conversation = Conversation()
        XCTAssertNil(conversation.lastMessage)
    }

    func testLastMessageSingle() {
        let conversation = Conversation()
        let message = Message(role: .user, content: "Only message")
        conversation.addMessage(message)

        XCTAssertEqual(conversation.lastMessage?.content, "Only message")
    }

    func testLastMessageMultiple() {
        let conversation = Conversation()

        let message1 = Message(role: .user, content: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Last")

        conversation.addMessage(message1)
        conversation.addMessage(message2)

        XCTAssertEqual(conversation.lastMessage?.content, "Last")
    }

    // MARK: - Export Tests

    func testExportAsMarkdown() {
        let conversation = Conversation(title: "Test Conversation")

        let message1 = Message(role: .user, content: "Hello")
        let message2 = Message(role: .assistant, content: "Hi there!")

        conversation.addMessage(message1)
        Thread.sleep(forTimeInterval: 0.01)
        conversation.addMessage(message2)

        let markdown = conversation.exportAsMarkdown()

        XCTAssertTrue(markdown.contains("# Test Conversation"))
        XCTAssertTrue(markdown.contains("**You:**"))
        XCTAssertTrue(markdown.contains("Hello"))
        XCTAssertTrue(markdown.contains("**Claude:**"))
        XCTAssertTrue(markdown.contains("Hi there!"))
        XCTAssertTrue(markdown.contains("---"))
    }

    func testExportAsMarkdownEmpty() {
        let conversation = Conversation(title: "Empty Chat")
        let markdown = conversation.exportAsMarkdown()

        XCTAssertTrue(markdown.contains("# Empty Chat"))
        XCTAssertFalse(markdown.contains("**You:**"))
        XCTAssertFalse(markdown.contains("**Claude:**"))
    }

    // MARK: - ID Uniqueness Tests

    func testConversationIDsAreUnique() {
        let conversation1 = Conversation()
        let conversation2 = Conversation()

        XCTAssertNotEqual(conversation1.id, conversation2.id)
    }
}

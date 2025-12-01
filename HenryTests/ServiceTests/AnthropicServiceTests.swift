import XCTest
@testable import Henry

final class AnthropicServiceTests: XCTestCase {

    // MARK: - API Message Tests

    func testAPIMessageCreation() {
        let message = APIMessage(role: "user", content: "Hello")

        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.content, "Hello")
    }

    func testAPIMessageCodable() throws {
        let message = APIMessage(role: "assistant", content: "Hello there!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIMessage.self, from: data)

        XCTAssertEqual(decoded.role, message.role)
        XCTAssertEqual(decoded.content, message.content)
    }

    // MARK: - Model Constants Tests

    func testDefaultModel() {
        XCTAssertEqual(AnthropicService.defaultModel, "claude-sonnet-4-20250514")
    }

    func testAvailableModels() {
        let models = AnthropicService.availableModels

        XCTAssertTrue(models.contains("claude-sonnet-4-20250514"))
        XCTAssertTrue(models.contains("claude-3-5-sonnet-20241022"))
        XCTAssertTrue(models.contains("claude-3-5-haiku-20241022"))
        XCTAssertTrue(models.contains("claude-3-opus-20240229"))
        XCTAssertEqual(models.count, 4)
    }

    // MARK: - Convert Messages Tests

    func testConvertMessagesEmpty() {
        let messages: [Message] = []
        let apiMessages = AnthropicService.convertMessages(messages)

        XCTAssertTrue(apiMessages.isEmpty)
    }

    func testConvertMessagesSingle() {
        let message = Message(role: .user, content: "Test")
        let apiMessages = AnthropicService.convertMessages([message])

        XCTAssertEqual(apiMessages.count, 1)
        XCTAssertEqual(apiMessages[0].role, "user")
        XCTAssertEqual(apiMessages[0].content, "Test")
    }

    func testConvertMessagesMultiple() {
        let message1 = Message(role: .user, content: "Question")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Answer")
        Thread.sleep(forTimeInterval: 0.01)
        let message3 = Message(role: .user, content: "Follow-up")

        let messages = [message1, message2, message3]
        let apiMessages = AnthropicService.convertMessages(messages)

        XCTAssertEqual(apiMessages.count, 3)
        XCTAssertEqual(apiMessages[0].role, "user")
        XCTAssertEqual(apiMessages[0].content, "Question")
        XCTAssertEqual(apiMessages[1].role, "assistant")
        XCTAssertEqual(apiMessages[1].content, "Answer")
        XCTAssertEqual(apiMessages[2].role, "user")
        XCTAssertEqual(apiMessages[2].content, "Follow-up")
    }

    func testConvertMessagesSortsByTimestamp() {
        // Create messages with explicit timestamps
        let message1 = Message(role: .user, content: "First")
        Thread.sleep(forTimeInterval: 0.01)
        let message2 = Message(role: .assistant, content: "Second")
        Thread.sleep(forTimeInterval: 0.01)
        let message3 = Message(role: .user, content: "Third")

        // Pass in wrong order
        let messages = [message3, message1, message2]
        let apiMessages = AnthropicService.convertMessages(messages)

        XCTAssertEqual(apiMessages[0].content, "First")
        XCTAssertEqual(apiMessages[1].content, "Second")
        XCTAssertEqual(apiMessages[2].content, "Third")
    }

    // MARK: - Tool Schema Tests

    func testToolSchema() throws {
        let schema = InputSchema(
            type: "object",
            properties: [
                "query": PropertySchema(type: "string", description: "Search query")
            ],
            required: ["query"]
        )

        let tool = Tool(
            name: "web_search",
            description: "Search the web",
            inputSchema: schema
        )

        XCTAssertEqual(tool.name, "web_search")
        XCTAssertEqual(tool.description, "Search the web")
        XCTAssertEqual(tool.inputSchema.type, "object")
        XCTAssertEqual(tool.inputSchema.properties["query"]?.type, "string")
        XCTAssertEqual(tool.inputSchema.required, ["query"])
    }

    func testToolCodable() throws {
        let schema = InputSchema(
            type: "object",
            properties: [
                "query": PropertySchema(type: "string", description: "The search query")
            ],
            required: ["query"]
        )

        let tool = Tool(
            name: "test_tool",
            description: "A test tool",
            inputSchema: schema
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(tool)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Tool.self, from: data)

        XCTAssertEqual(decoded.name, tool.name)
        XCTAssertEqual(decoded.description, tool.description)
    }

    // MARK: - Anthropic Request Tests

    func testAnthropicRequestCodable() throws {
        let request = AnthropicRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024,
            system: "You are a helpful assistant.",
            messages: [APIMessage(role: "user", content: "Hello")],
            stream: true,
            tools: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["model"] as? String, "claude-sonnet-4-20250514")
        XCTAssertEqual(json?["max_tokens"] as? Int, 1024)
        XCTAssertEqual(json?["system"] as? String, "You are a helpful assistant.")
        XCTAssertEqual(json?["stream"] as? Bool, true)
    }

    func testAnthropicRequestSnakeCaseKeys() throws {
        let request = AnthropicRequest(
            model: "test",
            maxTokens: 500,
            system: nil,
            messages: [],
            stream: false,
            tools: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!

        // Check that max_tokens is snake_case (not maxTokens)
        XCTAssertTrue(jsonString.contains("max_tokens"))
        XCTAssertFalse(jsonString.contains("maxTokens"))
    }

    // MARK: - Error Tests

    func testAnthropicErrorDescriptions() {
        let errors: [(AnthropicError, String)] = [
            (.invalidURL, "Invalid API URL"),
            (.invalidResponse, "Invalid response from API"),
            (.apiError("Test error"), "API Error: Test error"),
        ]

        for (error, expectedMessage) in errors {
            XCTAssertEqual(error.errorDescription, expectedMessage)
        }
    }

    func testNetworkErrorDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = AnthropicError.networkError(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Connection failed") ?? false)
    }

    func testDecodingErrorDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let error = AnthropicError.decodingError(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Decoding Error") ?? false)
    }

    // MARK: - Stream Event Tests

    func testStreamEventText() {
        let event = StreamEvent.text("Hello")

        if case .text(let text) = event {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text event")
        }
    }

    func testStreamEventToolUse() {
        let event = StreamEvent.toolUse(name: "web_search", input: ["query": "test"])

        if case .toolUse(let name, let input) = event {
            XCTAssertEqual(name, "web_search")
            XCTAssertEqual(input["query"] as? String, "test")
        } else {
            XCTFail("Expected toolUse event")
        }
    }

    func testStreamEventMessageStart() {
        let event = StreamEvent.messageStart

        if case .messageStart = event {
            // Success
        } else {
            XCTFail("Expected messageStart event")
        }
    }

    func testStreamEventMessageEnd() {
        let event = StreamEvent.messageEnd

        if case .messageEnd = event {
            // Success
        } else {
            XCTFail("Expected messageEnd event")
        }
    }

    func testStreamEventError() {
        let testError = AnthropicError.invalidURL
        let event = StreamEvent.error(testError)

        if case .error(let error) = event {
            XCTAssertTrue(error is AnthropicError)
        } else {
            XCTFail("Expected error event")
        }
    }
}

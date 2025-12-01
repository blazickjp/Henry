import Foundation
import SwiftData
@testable import Henry

// MARK: - Test Helpers

/// Helper to create in-memory model container for testing
@MainActor
func makeTestModelContainer() throws -> ModelContainer {
    let schema = Schema([
        Conversation.self,
        Message.self,
        Artifact.self
    ])

    let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
    )

    return try ModelContainer(for: schema, configurations: [configuration])
}

// MARK: - Test Data Factories

enum TestDataFactory {

    // MARK: - Conversations

    static func makeConversation(
        title: String = "Test Conversation",
        systemPrompt: String? = nil
    ) -> Conversation {
        Conversation(title: title, systemPrompt: systemPrompt)
    }

    static func makeConversationWithMessages(
        title: String = "Test Chat",
        messageCount: Int = 3
    ) -> Conversation {
        let conversation = Conversation(title: title)

        for i in 0..<messageCount {
            let role: MessageRole = i % 2 == 0 ? .user : .assistant
            let message = Message(role: role, content: "Message \(i + 1)")
            conversation.addMessage(message)
            Thread.sleep(forTimeInterval: 0.001) // Ensure different timestamps
        }

        return conversation
    }

    // MARK: - Messages

    static func makeUserMessage(content: String = "Test user message") -> Message {
        Message(role: .user, content: content)
    }

    static func makeAssistantMessage(content: String = "Test assistant message") -> Message {
        Message(role: .assistant, content: content)
    }

    static func makeMessageWithCodeBlock(language: String = "swift") -> Message {
        let content = """
        Here's some code:

        ```\(language)
        print("Hello, World!")
        ```
        """
        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()
        return message
    }

    // MARK: - Artifacts

    static func makeCodeArtifact(
        language: String = "swift",
        content: String = "print(\"test\")"
    ) -> Artifact {
        Artifact(type: .code, language: language, content: content, title: "\(language.capitalized) Code")
    }

    static func makeHTMLArtifact(content: String = "<h1>Hello</h1>") -> Artifact {
        Artifact(type: .html, language: "html", content: content, title: "HTML Preview")
    }

    static func makeMermaidArtifact() -> Artifact {
        let content = """
        graph TD
            A[Start] --> B[End]
        """
        return Artifact(type: .mermaid, language: "mermaid", content: content, title: "Diagram")
    }

    static func makeReactArtifact() -> Artifact {
        let content = """
        function App() {
            return <div>Hello React</div>;
        }
        """
        return Artifact(type: .react, language: "jsx", content: content, title: "React Component")
    }

    static func makeSVGArtifact() -> Artifact {
        let content = """
        <svg width="100" height="100">
            <circle cx="50" cy="50" r="40" fill="blue"/>
        </svg>
        """
        return Artifact(type: .svg, language: "svg", content: content, title: "SVG Image")
    }

    // MARK: - Search Results

    static func makeSearchResult(
        title: String = "Test Result",
        url: String = "https://example.com",
        snippet: String = "Test snippet"
    ) -> SearchResult {
        SearchResult(title: title, url: url, snippet: snippet)
    }

    static func makeSearchResults(count: Int = 5) -> [SearchResult] {
        (0..<count).map { i in
            SearchResult(
                title: "Result \(i + 1)",
                url: "https://example\(i + 1).com",
                snippet: "Snippet for result \(i + 1)"
            )
        }
    }

    // MARK: - Web Page Content

    static func makeWebPageContent(
        url: String = "https://example.com",
        title: String = "Example Page",
        content: String = "Page content here"
    ) -> WebPageContent {
        WebPageContent(url: url, title: title, content: content, fetchedAt: Date())
    }

    // MARK: - API Messages

    static func makeAPIMessage(role: String = "user", content: String = "Test") -> APIMessage {
        APIMessage(role: role, content: content)
    }

    static func makeAPIMessages(count: Int = 3) -> [APIMessage] {
        (0..<count).map { i in
            let role = i % 2 == 0 ? "user" : "assistant"
            return APIMessage(role: role, content: "Message \(i + 1)")
        }
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Wait for a condition to become true
    func wait(
        for condition: @escaping () -> Bool,
        timeout: TimeInterval = 5.0,
        message: String = "Condition was not met"
    ) {
        let expectation = XCTestExpectation(description: message)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                expectation.fulfill()
                timer.invalidate()
            }
        }

        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }

    /// Assert that an async operation throws a specific error
    func assertThrowsError<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }
}

import XCTest
import SwiftData
@testable import Henry

final class MessageTests: XCTestCase {

    // MARK: - Initialization Tests

    func testMessageInitializationUser() {
        let message = Message(role: .user, content: "Hello, Claude!")

        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello, Claude!")
        XCTAssertNotNil(message.timestamp)
        XCTAssertTrue(message.artifacts.isEmpty)
    }

    func testMessageInitializationAssistant() {
        let message = Message(role: .assistant, content: "Hello! How can I help?")

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello! How can I help?")
    }

    // MARK: - API Format Tests

    func testAPIFormatUser() {
        let message = Message(role: .user, content: "Test message")
        let apiFormat = message.apiFormat

        XCTAssertEqual(apiFormat["role"], "user")
        XCTAssertEqual(apiFormat["content"], "Test message")
    }

    func testAPIFormatAssistant() {
        let message = Message(role: .assistant, content: "Response text")
        let apiFormat = message.apiFormat

        XCTAssertEqual(apiFormat["role"], "assistant")
        XCTAssertEqual(apiFormat["content"], "Response text")
    }

    // MARK: - Artifact Extraction Tests

    func testExtractSingleCodeBlock() {
        let content = """
        Here is some Swift code:

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```

        That's it!
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .code)
        XCTAssertEqual(message.artifacts[0].language, "swift")
        XCTAssertTrue(message.artifacts[0].content.contains("func hello()"))
    }

    func testExtractMultipleCodeBlocks() {
        let content = """
        Here's Python:

        ```python
        print("Hello")
        ```

        And JavaScript:

        ```javascript
        console.log("Hello");
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 2)
        XCTAssertEqual(message.artifacts[0].language, "python")
        XCTAssertEqual(message.artifacts[1].language, "javascript")
    }

    func testExtractHTMLArtifact() {
        let content = """
        Here's some HTML:

        ```html
        <div>
            <h1>Hello</h1>
            <p>World</p>
        </div>
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .html)
        XCTAssertEqual(message.artifacts[0].language, "html")
    }

    func testExtractMarkdownArtifact() {
        let content = """
        Here's markdown:

        ```markdown
        # Title
        Some **bold** text
        ```

        And also:

        ```md
        ## Subtitle
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 2)
        XCTAssertEqual(message.artifacts[0].type, .markdown)
        XCTAssertEqual(message.artifacts[1].type, .markdown)
    }

    func testExtractMermaidArtifact() {
        let content = """
        Here's a diagram:

        ```mermaid
        graph TD
            A[Start] --> B[End]
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .mermaid)
    }

    func testExtractSVGArtifact() {
        let content = """
        Here's an SVG:

        ```svg
        <svg width="100" height="100">
            <circle cx="50" cy="50" r="40"/>
        </svg>
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .svg)
    }

    func testExtractReactArtifacts() {
        let jsxContent = """
        ```jsx
        function App() {
            return <div>Hello</div>;
        }
        ```
        """

        let tsxContent = """
        ```tsx
        const App: React.FC = () => <div>Hello</div>;
        ```
        """

        let reactContent = """
        ```react
        function Component() {
            return <span>Hi</span>;
        }
        ```
        """

        let message1 = Message(role: .assistant, content: jsxContent)
        message1.extractArtifacts()
        XCTAssertEqual(message1.artifacts[0].type, .react)

        let message2 = Message(role: .assistant, content: tsxContent)
        message2.extractArtifacts()
        XCTAssertEqual(message2.artifacts[0].type, .react)

        let message3 = Message(role: .assistant, content: reactContent)
        message3.extractArtifacts()
        XCTAssertEqual(message3.artifacts[0].type, .react)
    }

    func testExtractCodeBlockWithoutLanguage() {
        let content = """
        Here's some code:

        ```
        some generic code
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        // Code block without language identifier should be treated as text
        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .code)
        XCTAssertEqual(message.artifacts[0].language, "")
    }

    func testNoCodeBlocks() {
        let content = "This is just plain text with no code blocks."

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertTrue(message.artifacts.isEmpty)
    }

    func testArtifactTitleGeneration() {
        let content = """
        ```python
        print("test")
        ```
        """

        let message = Message(role: .assistant, content: content)
        message.extractArtifacts()

        XCTAssertEqual(message.artifacts[0].title, "Python Code")
    }

    // MARK: - MessageRole Codable Tests

    func testMessageRoleCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for role in [MessageRole.user, .assistant] {
            let encoded = try encoder.encode(role)
            let decoded = try decoder.decode(MessageRole.self, from: encoded)
            XCTAssertEqual(role, decoded)
        }
    }

    func testMessageRoleRawValue() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
    }
}

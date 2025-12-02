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

        // Code block without language identifier defaults to "text" type
        XCTAssertEqual(message.artifacts.count, 1)
        XCTAssertEqual(message.artifacts[0].type, .code)
        XCTAssertEqual(message.artifacts[0].language, "text")
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

    // MARK: - Multimodal API Format Tests

    func testAPIFormatMultimodalWithTextAndImage() {
        let image = createTestImage()
        let message = Message(role: .user, content: "What is this?", uiImages: [image])
        let apiFormat = message.apiFormatMultimodal

        XCTAssertEqual(apiFormat["role"] as? String, "user")

        guard let content = apiFormat["content"] as? [[String: Any]] else {
            XCTFail("Content should be array of blocks")
            return
        }

        // Should have both image and text blocks
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "image")
        XCTAssertEqual(content[1]["type"] as? String, "text")
        XCTAssertEqual(content[1]["text"] as? String, "What is this?")
    }

    func testAPIFormatMultimodalEmptyTextWithImage() {
        // This test exposes the bug: empty text with images should still produce valid API format
        let image = createTestImage()
        let message = Message(role: .user, content: "", uiImages: [image])
        let apiFormat = message.apiFormatMultimodal

        guard let content = apiFormat["content"] as? [[String: Any]] else {
            XCTFail("Content should be array of blocks")
            return
        }

        // BUG: With empty text and an image, we need at least a placeholder text
        // The Anthropic API requires non-empty content
        // After fix: Should have image block + placeholder text block
        XCTAssertGreaterThanOrEqual(content.count, 1, "Should have at least image block")

        // Check that we have a text block (after fix this should pass)
        let hasTextBlock = content.contains { $0["type"] as? String == "text" }
        XCTAssertTrue(hasTextBlock, "Multimodal message with image should always have a text block for API compatibility")
    }

    func testAPIFormatMultimodalWhitespaceTextWithImage() {
        let image = createTestImage()
        let message = Message(role: .user, content: "   \n\t   ", uiImages: [image])
        let apiFormat = message.apiFormatMultimodal

        guard let content = apiFormat["content"] as? [[String: Any]] else {
            XCTFail("Content should be array of blocks")
            return
        }

        // Whitespace-only text should be treated similarly to empty text
        // After fix: Should have a valid text block
        let hasTextBlock = content.contains { $0["type"] as? String == "text" }
        XCTAssertTrue(hasTextBlock, "Multimodal message should have text block even with whitespace-only content")
    }

    func testAPIFormatMultimodalTextOnly() {
        let message = Message(role: .user, content: "Just text, no image")

        // Text-only messages should use the simpler apiFormat
        XCTAssertFalse(message.hasImages)
        XCTAssertFalse(message.requiresMultimodalFormat)

        // apiFormat should be simple string content
        let simpleFormat = message.apiFormat
        XCTAssertEqual(simpleFormat["content"], "Just text, no image")
    }

    func testHasImages() {
        let textOnlyMessage = Message(role: .user, content: "No images")
        XCTAssertFalse(textOnlyMessage.hasImages)

        let image = createTestImage()
        let imageMessage = Message(role: .user, content: "With image", uiImages: [image])
        XCTAssertTrue(imageMessage.hasImages)
    }

    func testImageAttachmentEncodingDecoding() {
        let image = createTestImage()
        let message = Message(role: .user, content: "Test", uiImages: [image])

        // Verify image was stored
        XCTAssertEqual(message.imageAttachments.count, 1)

        let attachment = message.imageAttachments[0]
        XCTAssertEqual(attachment.mediaType, "image/png")
        XCTAssertGreaterThan(attachment.imageData.count, 0)
        XCTAssertNotNil(attachment.image)
    }

    // MARK: - Helper Methods

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

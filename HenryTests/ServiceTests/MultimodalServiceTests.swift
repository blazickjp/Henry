import XCTest
import UIKit
@testable import Henry

final class MultimodalServiceTests: XCTestCase {

    // MARK: - Content Block Tests

    func testTextContentBlock() {
        let block = APIContentBlock.text("Hello, world!")
        let dict = block.dictionary

        XCTAssertEqual(dict["type"] as? String, "text")
        XCTAssertEqual(dict["text"] as? String, "Hello, world!")
    }

    func testImageContentBlock() {
        let block = APIContentBlock.image(mediaType: "image/png", base64Data: "iVBORw0KGgo=")
        let dict = block.dictionary

        XCTAssertEqual(dict["type"] as? String, "image")

        guard let source = dict["source"] as? [String: Any] else {
            XCTFail("Source should be dictionary")
            return
        }

        XCTAssertEqual(source["type"] as? String, "base64")
        XCTAssertEqual(source["media_type"] as? String, "image/png")
        XCTAssertEqual(source["data"] as? String, "iVBORw0KGgo=")
    }

    // MARK: - Multimodal Message Tests

    func testMultimodalMessageDictionary() {
        let message = APIMultimodalMessage(
            role: "user",
            content: [
                .image(mediaType: "image/png", base64Data: "base64data"),
                .text("What is in this image?")
            ]
        )

        let dict = message.dictionary

        XCTAssertEqual(dict["role"] as? String, "user")

        guard let content = dict["content"] as? [[String: Any]] else {
            XCTFail("Content should be array")
            return
        }

        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "image")
        XCTAssertEqual(content[1]["type"] as? String, "text")
    }

    // MARK: - Convert Messages Tests

    func testConvertMessagesMultimodalTextOnly() {
        let message = Message(role: .user, content: "Just text")
        let result = AnthropicService.convertMessagesMultimodal([message])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["role"] as? String, "user")
        XCTAssertEqual(result[0]["content"] as? String, "Just text")
    }

    func testConvertMessagesMultimodalWithImage() {
        let image = createTestImage()
        let message = Message(role: .user, content: "Look at this", uiImages: [image])
        let result = AnthropicService.convertMessagesMultimodal([message])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["role"] as? String, "user")

        // Content should be array for multimodal
        XCTAssertTrue(result[0]["content"] is [[String: Any]])
    }

    func testConvertMessagesMultimodalMixed() {
        let textMessage = Message(role: .user, content: "Hello")
        Thread.sleep(forTimeInterval: 0.01)

        let image = createTestImage()
        let imageMessage = Message(role: .user, content: "Look", uiImages: [image])
        Thread.sleep(forTimeInterval: 0.01)

        let assistantMessage = Message(role: .assistant, content: "I see")

        let messages = [textMessage, imageMessage, assistantMessage]
        let result = AnthropicService.convertMessagesMultimodal(messages)

        XCTAssertEqual(result.count, 3)

        // First message - text only (string content)
        XCTAssertEqual(result[0]["content"] as? String, "Hello")

        // Second message - with image (array content)
        XCTAssertTrue(result[1]["content"] is [[String: Any]])

        // Third message - text only (string content)
        XCTAssertEqual(result[2]["content"] as? String, "I see")
    }

    func testHasMultimodalContentTrue() {
        let image = createTestImage()
        let message = Message(role: .user, content: "Image", uiImages: [image])

        XCTAssertTrue(AnthropicService.hasMultimodalContent([message]))
    }

    func testHasMultimodalContentFalse() {
        let message = Message(role: .user, content: "Just text")

        XCTAssertFalse(AnthropicService.hasMultimodalContent([message]))
    }

    func testHasMultimodalContentMixed() {
        let textMessage = Message(role: .user, content: "Text")
        let image = createTestImage()
        let imageMessage = Message(role: .user, content: "Image", uiImages: [image])

        let messages = [textMessage, imageMessage]
        XCTAssertTrue(AnthropicService.hasMultimodalContent(messages))
    }

    func testHasMultimodalContentEmpty() {
        XCTAssertFalse(AnthropicService.hasMultimodalContent([]))
    }

    // MARK: - Message Order Tests

    func testMultimodalMessagesPreserveOrder() {
        var messages: [Message] = []

        for i in 0..<5 {
            let role: MessageRole = i % 2 == 0 ? .user : .assistant
            let message = Message(role: role, content: "Message \(i)")
            messages.append(message)
            Thread.sleep(forTimeInterval: 0.01)
        }

        let result = AnthropicService.convertMessagesMultimodal(messages)

        for i in 0..<5 {
            XCTAssertEqual(result[i]["content"] as? String, "Message \(i)")
        }
    }

    // MARK: - Helper Methods

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

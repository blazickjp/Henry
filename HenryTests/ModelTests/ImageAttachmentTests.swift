import XCTest
import UIKit
@testable import Henry

final class ImageAttachmentTests: XCTestCase {

    // MARK: - Initialization Tests

    func testImageAttachmentFromUIImage() {
        let image = createTestImage(width: 100, height: 100)
        let attachment = ImageAttachment(image: image)

        XCTAssertNotNil(attachment)
        XCTAssertNotNil(attachment?.id)
        XCTAssertEqual(attachment?.mediaType, "image/png")
        XCTAssertEqual(attachment?.width, 100)
        XCTAssertEqual(attachment?.height, 100)
        XCTAssertFalse(attachment?.imageData.isEmpty ?? true)
    }

    func testImageAttachmentFromData() {
        let data = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let attachment = ImageAttachment(data: data, mediaType: "image/png", width: 50, height: 50)

        XCTAssertNotNil(attachment.id)
        XCTAssertEqual(attachment.mediaType, "image/png")
        XCTAssertEqual(attachment.width, 50)
        XCTAssertEqual(attachment.height, 50)
        XCTAssertEqual(attachment.imageData, data)
    }

    func testBase64Encoding() {
        let testData = Data("Hello, World!".utf8)
        let attachment = ImageAttachment(data: testData, mediaType: "image/png", width: 10, height: 10)

        let base64 = attachment.base64Encoded
        XCTAssertEqual(base64, testData.base64EncodedString())
    }

    func testImageReconstruction() {
        let originalImage = createTestImage(width: 50, height: 50)
        let attachment = ImageAttachment(image: originalImage)

        XCTAssertNotNil(attachment)

        let reconstructedImage = attachment?.image
        XCTAssertNotNil(reconstructedImage)
    }

    // MARK: - Codable Tests

    func testImageAttachmentCodable() throws {
        let image = createTestImage(width: 20, height: 20)
        guard let attachment = ImageAttachment(image: image) else {
            XCTFail("Failed to create attachment")
            return
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(attachment)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageAttachment.self, from: data)

        XCTAssertEqual(decoded.id, attachment.id)
        XCTAssertEqual(decoded.mediaType, attachment.mediaType)
        XCTAssertEqual(decoded.width, attachment.width)
        XCTAssertEqual(decoded.height, attachment.height)
        XCTAssertEqual(decoded.imageData, attachment.imageData)
    }

    // MARK: - Equatable Tests

    func testImageAttachmentEquatable() {
        let data = Data([1, 2, 3, 4])
        let attachment1 = ImageAttachment(data: data, mediaType: "image/png", width: 10, height: 10)
        let attachment2 = ImageAttachment(data: data, mediaType: "image/png", width: 10, height: 10)

        // Different IDs, so not equal
        XCTAssertNotEqual(attachment1, attachment2)

        // Same attachment should equal itself
        XCTAssertEqual(attachment1, attachment1)
    }

    // MARK: - Message Integration Tests

    func testMessageWithImages() {
        let image = createTestImage(width: 100, height: 100)
        let message = Message(role: .user, content: "Look at this image", uiImages: [image])

        XCTAssertTrue(message.hasImages)
        XCTAssertEqual(message.imageAttachments.count, 1)
    }

    func testMessageWithoutImages() {
        let message = Message(role: .user, content: "Just text")

        XCTAssertFalse(message.hasImages)
        XCTAssertTrue(message.imageAttachments.isEmpty)
    }

    func testMessageAddImage() {
        let message = Message(role: .user, content: "Initial")
        XCTAssertFalse(message.hasImages)

        let image = createTestImage(width: 50, height: 50)
        message.addImage(image)

        XCTAssertTrue(message.hasImages)
        XCTAssertEqual(message.imageAttachments.count, 1)
    }

    func testMessageMultipleImages() {
        let image1 = createTestImage(width: 100, height: 100)
        let image2 = createTestImage(width: 200, height: 200)
        let message = Message(role: .user, content: "Multiple images", uiImages: [image1, image2])

        XCTAssertEqual(message.imageAttachments.count, 2)
    }

    func testMessageRequiresMultimodalFormat() {
        let textMessage = Message(role: .user, content: "Just text")
        XCTAssertFalse(textMessage.requiresMultimodalFormat)

        let image = createTestImage(width: 50, height: 50)
        let imageMessage = Message(role: .user, content: "With image", uiImages: [image])
        XCTAssertTrue(imageMessage.requiresMultimodalFormat)
    }

    // MARK: - API Format Tests

    func testAPIFormatMultimodalWithImage() {
        let image = createTestImage(width: 50, height: 50)
        let message = Message(role: .user, content: "Describe this", uiImages: [image])

        let format = message.apiFormatMultimodal

        XCTAssertEqual(format["role"] as? String, "user")

        guard let content = format["content"] as? [[String: Any]] else {
            XCTFail("Content should be array of dictionaries")
            return
        }

        // Should have image block and text block
        XCTAssertEqual(content.count, 2)

        // First should be image
        XCTAssertEqual(content[0]["type"] as? String, "image")

        // Second should be text
        XCTAssertEqual(content[1]["type"] as? String, "text")
        XCTAssertEqual(content[1]["text"] as? String, "Describe this")
    }

    func testAPIFormatMultimodalImageSource() {
        let image = createTestImage(width: 50, height: 50)
        guard let attachment = ImageAttachment(image: image) else {
            XCTFail("Failed to create attachment")
            return
        }

        let message = Message(role: .user, content: "Test", images: [attachment])
        let format = message.apiFormatMultimodal

        guard let content = format["content"] as? [[String: Any]],
              let imageBlock = content.first,
              let source = imageBlock["source"] as? [String: Any] else {
            XCTFail("Invalid format structure")
            return
        }

        XCTAssertEqual(source["type"] as? String, "base64")
        XCTAssertEqual(source["media_type"] as? String, "image/png")
        XCTAssertNotNil(source["data"] as? String)
    }

    // MARK: - Helper Methods

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

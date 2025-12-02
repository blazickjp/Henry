import Foundation
import SwiftData
import UIKit

enum MessageRole: String, Codable {
    case user
    case assistant
}

/// Represents an image attachment in a message
struct ImageAttachment: Codable, Equatable {
    let id: UUID
    let imageData: Data
    let mediaType: String
    let width: Int
    let height: Int

    init?(image: UIImage, mediaType: String = "image/png") {
        guard let data = image.pngData() else { return nil }
        self.id = UUID()
        self.imageData = data
        self.mediaType = mediaType
        self.width = Int(image.size.width)
        self.height = Int(image.size.height)
    }

    init(data: Data, mediaType: String = "image/png", width: Int, height: Int) {
        self.id = UUID()
        self.imageData = data
        self.mediaType = mediaType
        self.width = width
        self.height = height
    }

    var image: UIImage? {
        UIImage(data: imageData)
    }

    /// Base64 encoded image data for API
    var base64Encoded: String {
        imageData.base64EncodedString()
    }
}

@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var artifacts: [Artifact]
    var conversation: Conversation?

    /// Stored as JSON-encoded Data for SwiftData compatibility
    var imageAttachmentsData: Data?

    /// Computed property to access image attachments
    var imageAttachments: [ImageAttachment] {
        get {
            guard let data = imageAttachmentsData else { return [] }
            return (try? JSONDecoder().decode([ImageAttachment].self, from: data)) ?? []
        }
        set {
            imageAttachmentsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Check if message has images
    var hasImages: Bool {
        !imageAttachments.isEmpty
    }

    init(role: MessageRole, content: String, images: [ImageAttachment] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.artifacts = []
        self.imageAttachmentsData = try? JSONEncoder().encode(images)
    }

    /// Convenience initializer with UIImages
    convenience init(role: MessageRole, content: String, uiImages: [UIImage]) {
        let attachments = uiImages.compactMap { ImageAttachment(image: $0) }
        self.init(role: role, content: content, images: attachments)
    }

    /// Add an image attachment
    func addImage(_ image: UIImage) {
        guard let attachment = ImageAttachment(image: image) else { return }
        var current = imageAttachments
        current.append(attachment)
        imageAttachments = current
    }

    /// Extract artifacts from message content (code blocks, etc.)
    func extractArtifacts() {
        let codeBlockPattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) else { return }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        for match in matches {
            let languageRange = Range(match.range(at: 1), in: content)
            let codeRange = Range(match.range(at: 2), in: content)

            let language = languageRange.map { String(content[$0]) } ?? "text"
            let code = codeRange.map { String(content[$0]) } ?? ""

            let artifactType: ArtifactType = {
                switch language.lowercased() {
                case "html": return .html
                case "markdown", "md": return .markdown
                case "mermaid": return .mermaid
                case "svg": return .svg
                case "react", "jsx", "tsx": return .react
                default: return .code
                }
            }()

            let artifact = Artifact(
                type: artifactType,
                language: language,
                content: code.trimmingCharacters(in: .whitespacesAndNewlines),
                title: "\(language.capitalized) Code"
            )
            artifacts.append(artifact)
        }
    }
}

extension Message {
    /// Convert to Anthropic API message format (text only)
    var apiFormat: [String: String] {
        ["role": role.rawValue, "content": content]
    }

    /// Convert to Anthropic API multimodal format (with images)
    var apiFormatMultimodal: [String: Any] {
        var contentBlocks: [[String: Any]] = []

        // Add images first
        for attachment in imageAttachments {
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": attachment.mediaType,
                    "data": attachment.base64Encoded
                ]
            ])
        }

        // Add text content
        if !content.isEmpty {
            contentBlocks.append([
                "type": "text",
                "text": content
            ])
        }

        return [
            "role": role.rawValue,
            "content": contentBlocks
        ]
    }

    /// Check if this message needs multimodal format
    var requiresMultimodalFormat: Bool {
        hasImages
    }
}

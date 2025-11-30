import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
}

@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var artifacts: [Artifact]
    var conversation: Conversation?

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.artifacts = []
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
    /// Convert to Anthropic API message format
    var apiFormat: [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

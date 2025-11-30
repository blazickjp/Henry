import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation) var messages: [Message]
    var systemPrompt: String?

    init(title: String = "New Chat", systemPrompt: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
        self.systemPrompt = systemPrompt
    }

    /// Add a message to the conversation
    func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()

        // Auto-generate title from first user message
        if title == "New Chat", message.role == .user {
            generateTitle(from: message.content)
        }
    }

    /// Generate a title from the first message content
    private func generateTitle(from content: String) {
        let maxLength = 40
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= maxLength {
            title = trimmed
        } else {
            let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            title = String(trimmed[..<endIndex]) + "..."
        }
    }

    /// Get messages in API format for Anthropic
    var messagesForAPI: [[String: String]] {
        messages.sorted { $0.timestamp < $1.timestamp }.map { $0.apiFormat }
    }

    /// Get the last message
    var lastMessage: Message? {
        messages.sorted { $0.timestamp < $1.timestamp }.last
    }

    /// Export conversation as markdown
    func exportAsMarkdown() -> String {
        var md = "# \(title)\n\n"
        md += "_Created: \(createdAt.formatted())_\n\n---\n\n"

        for message in messages.sorted(by: { $0.timestamp < $1.timestamp }) {
            let rolePrefix = message.role == .user ? "**You:**" : "**Claude:**"
            md += "\(rolePrefix)\n\n\(message.content)\n\n---\n\n"
        }

        return md
    }
}

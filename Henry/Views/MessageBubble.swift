import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: Message
    let onArtifactTap: (Artifact) -> Void

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: Spacing.sm) {
                // Message Content
                messageContent

                // Artifacts (if any)
                if !message.artifacts.isEmpty {
                    artifactButtons
                }

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        if isUser {
            Text(message.content)
                .font(.chatMessage)
                .chatBubble(isUser: true)
        } else {
            Markdown(message.content)
                .markdownTheme(.claude)
                .chatBubble(isUser: false)
                .frame(maxWidth: 600, alignment: .leading)
        }
    }

    // MARK: - Artifact Buttons

    private var artifactButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(message.artifacts) { artifact in
                ArtifactButton(artifact: artifact) {
                    onArtifactTap(artifact)
                }
            }
        }
    }
}

// MARK: - Artifact Button

struct ArtifactButton: View {
    let artifact: Artifact
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                artifactIcon
                    .font(.title3)
                    .foregroundColor(.claudeOrange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)

                    Text(artifactTypeLabel)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.artifactBackground)
            .cornerRadius(Spacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.sm)
                    .stroke(Color.artifactBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var artifactIcon: Image {
        switch artifact.type {
        case .code:
            return Image(systemName: "doc.text")
        case .html:
            return Image(systemName: "globe")
        case .markdown:
            return Image(systemName: "doc.richtext")
        case .mermaid:
            return Image(systemName: "chart.bar.doc.horizontal")
        case .svg:
            return Image(systemName: "photo")
        case .react:
            return Image(systemName: "atom")
        }
    }

    private var artifactTypeLabel: String {
        switch artifact.type {
        case .code:
            return "\(artifact.language.capitalized) code"
        case .html:
            return "HTML preview"
        case .markdown:
            return "Markdown document"
        case .mermaid:
            return "Mermaid diagram"
        case .svg:
            return "SVG image"
        case .react:
            return "React component"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MessageBubble(
            message: {
                let m = Message(role: .user, content: "Can you show me a Swift example?")
                return m
            }(),
            onArtifactTap: { _ in }
        )

        MessageBubble(
            message: {
                let m = Message(role: .assistant, content: "Here's a simple Swift example:\n\n```swift\nprint(\"Hello, World!\")\n```")
                m.extractArtifacts()
                return m
            }(),
            onArtifactTap: { _ in }
        )
    }
    .padding()
}

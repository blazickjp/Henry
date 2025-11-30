import Foundation
import SwiftData

enum ArtifactType: String, Codable {
    case code
    case html
    case markdown
    case mermaid
    case svg
    case react
}

@Model
final class Artifact {
    var id: UUID
    var type: ArtifactType
    var language: String
    var content: String
    var title: String
    var createdAt: Date
    var message: Message?

    init(type: ArtifactType, language: String, content: String, title: String) {
        self.id = UUID()
        self.type = type
        self.language = language
        self.content = content
        self.title = title
        self.createdAt = Date()
    }

    /// Returns appropriate file extension for this artifact
    var fileExtension: String {
        switch type {
        case .code:
            return languageExtension
        case .html:
            return "html"
        case .markdown:
            return "md"
        case .mermaid:
            return "mmd"
        case .svg:
            return "svg"
        case .react:
            return "tsx"
        }
    }

    private var languageExtension: String {
        switch language.lowercased() {
        case "swift": return "swift"
        case "python", "py": return "py"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        case "rust": return "rs"
        case "go": return "go"
        case "java": return "java"
        case "kotlin": return "kt"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "ruby", "rb": return "rb"
        case "php": return "php"
        case "shell", "bash", "sh": return "sh"
        case "sql": return "sql"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "css": return "css"
        default: return "txt"
        }
    }

    /// Check if this artifact can be previewed in a WebView
    var isPreviewable: Bool {
        switch type {
        case .html, .svg, .react, .mermaid:
            return true
        case .code, .markdown:
            return false
        }
    }
}

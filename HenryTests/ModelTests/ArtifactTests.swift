import XCTest
import SwiftData
@testable import Henry

final class ArtifactTests: XCTestCase {

    // MARK: - Initialization Tests

    func testArtifactInitialization() {
        let artifact = Artifact(
            type: .code,
            language: "swift",
            content: "print(\"Hello\")",
            title: "Test Code"
        )

        XCTAssertNotNil(artifact.id)
        XCTAssertEqual(artifact.type, .code)
        XCTAssertEqual(artifact.language, "swift")
        XCTAssertEqual(artifact.content, "print(\"Hello\")")
        XCTAssertEqual(artifact.title, "Test Code")
        XCTAssertNotNil(artifact.createdAt)
    }

    func testArtifactTypes() {
        let types: [ArtifactType] = [.code, .html, .markdown, .mermaid, .svg, .react]

        for type in types {
            let artifact = Artifact(type: type, language: "test", content: "content", title: "Title")
            XCTAssertEqual(artifact.type, type)
        }
    }

    // MARK: - File Extension Tests

    func testFileExtensionForCode() {
        let testCases: [(language: String, expected: String)] = [
            ("swift", "swift"),
            ("python", "py"),
            ("py", "py"),
            ("javascript", "js"),
            ("js", "js"),
            ("typescript", "ts"),
            ("ts", "ts"),
            ("rust", "rs"),
            ("go", "go"),
            ("java", "java"),
            ("kotlin", "kt"),
            ("c", "c"),
            ("cpp", "cpp"),
            ("c++", "cpp"),
            ("ruby", "rb"),
            ("rb", "rb"),
            ("php", "php"),
            ("shell", "sh"),
            ("bash", "sh"),
            ("sh", "sh"),
            ("sql", "sql"),
            ("json", "json"),
            ("yaml", "yaml"),
            ("yml", "yaml"),
            ("xml", "xml"),
            ("css", "css"),
            ("unknown", "txt")
        ]

        for testCase in testCases {
            let artifact = Artifact(type: .code, language: testCase.language, content: "", title: "")
            XCTAssertEqual(artifact.fileExtension, testCase.expected, "Failed for language: \(testCase.language)")
        }
    }

    func testFileExtensionForNonCodeTypes() {
        let artifact1 = Artifact(type: .html, language: "html", content: "", title: "")
        XCTAssertEqual(artifact1.fileExtension, "html")

        let artifact2 = Artifact(type: .markdown, language: "md", content: "", title: "")
        XCTAssertEqual(artifact2.fileExtension, "md")

        let artifact3 = Artifact(type: .mermaid, language: "mermaid", content: "", title: "")
        XCTAssertEqual(artifact3.fileExtension, "mmd")

        let artifact4 = Artifact(type: .svg, language: "svg", content: "", title: "")
        XCTAssertEqual(artifact4.fileExtension, "svg")

        let artifact5 = Artifact(type: .react, language: "tsx", content: "", title: "")
        XCTAssertEqual(artifact5.fileExtension, "tsx")
    }

    // MARK: - Previewable Tests

    func testIsPreviewable() {
        let previewableTypes: [ArtifactType] = [.html, .svg, .react, .mermaid]
        let nonPreviewableTypes: [ArtifactType] = [.code, .markdown]

        for type in previewableTypes {
            let artifact = Artifact(type: type, language: "test", content: "", title: "")
            XCTAssertTrue(artifact.isPreviewable, "Type \(type) should be previewable")
        }

        for type in nonPreviewableTypes {
            let artifact = Artifact(type: type, language: "test", content: "", title: "")
            XCTAssertFalse(artifact.isPreviewable, "Type \(type) should not be previewable")
        }
    }

    // MARK: - Codable Tests

    func testArtifactTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in [ArtifactType.code, .html, .markdown, .mermaid, .svg, .react] {
            let encoded = try encoder.encode(type)
            let decoded = try decoder.decode(ArtifactType.self, from: encoded)
            XCTAssertEqual(type, decoded)
        }
    }
}

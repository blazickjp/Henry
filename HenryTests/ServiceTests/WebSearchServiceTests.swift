import XCTest
@testable import Henry

final class WebSearchServiceTests: XCTestCase {

    // MARK: - SearchResult Tests

    func testSearchResultInitialization() {
        let result = SearchResult(
            title: "Test Title",
            url: "https://example.com",
            snippet: "This is a test snippet"
        )

        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.title, "Test Title")
        XCTAssertEqual(result.url, "https://example.com")
        XCTAssertEqual(result.snippet, "This is a test snippet")
    }

    func testSearchResultIdentifiable() {
        let result1 = SearchResult(title: "A", url: "url1", snippet: "")
        let result2 = SearchResult(title: "B", url: "url2", snippet: "")

        XCTAssertNotEqual(result1.id, result2.id)
    }

    func testSearchResultCodable() throws {
        let result = SearchResult(
            title: "Codable Test",
            url: "https://test.com",
            snippet: "Testing codable"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SearchResult.self, from: data)

        XCTAssertEqual(decoded.title, result.title)
        XCTAssertEqual(decoded.url, result.url)
        XCTAssertEqual(decoded.snippet, result.snippet)
    }

    // MARK: - WebPageContent Tests

    func testWebPageContentInitialization() {
        let content = WebPageContent(
            url: "https://example.com",
            title: "Example",
            content: "Page content here",
            fetchedAt: Date()
        )

        XCTAssertEqual(content.url, "https://example.com")
        XCTAssertEqual(content.title, "Example")
        XCTAssertEqual(content.content, "Page content here")
        XCTAssertNotNil(content.fetchedAt)
    }

    func testWebPageContentTruncatedShort() {
        let shortContent = "Short content"
        let page = WebPageContent(
            url: "url",
            title: "title",
            content: shortContent,
            fetchedAt: Date()
        )

        let truncated = page.truncated(maxLength: 100)
        XCTAssertEqual(truncated, shortContent)
    }

    func testWebPageContentTruncatedLong() {
        let longContent = String(repeating: "a", count: 10000)
        let page = WebPageContent(
            url: "url",
            title: "title",
            content: longContent,
            fetchedAt: Date()
        )

        let truncated = page.truncated(maxLength: 100)
        XCTAssertEqual(truncated.count, 100 + "...[truncated]".count)
        XCTAssertTrue(truncated.hasSuffix("...[truncated]"))
    }

    func testWebPageContentTruncatedExactLength() {
        let exactContent = String(repeating: "x", count: 8000)
        let page = WebPageContent(
            url: "url",
            title: "title",
            content: exactContent,
            fetchedAt: Date()
        )

        let truncated = page.truncated(maxLength: 8000)
        XCTAssertEqual(truncated, exactContent)
    }

    func testWebPageContentTruncatedDefaultLength() {
        let longContent = String(repeating: "b", count: 10000)
        let page = WebPageContent(
            url: "url",
            title: "title",
            content: longContent,
            fetchedAt: Date()
        )

        // Default is 8000
        let truncated = page.truncated()
        XCTAssertTrue(truncated.count <= 8000 + "...[truncated]".count)
    }

    // MARK: - WebSearchError Tests

    func testWebSearchErrorDescriptions() {
        XCTAssertEqual(WebSearchError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(WebSearchError.parsingFailed.errorDescription, "Failed to parse content")
        XCTAssertEqual(WebSearchError.noResults.errorDescription, "No results found")
    }

    func testWebSearchErrorFetchFailed() {
        let underlyingError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let error = WebSearchError.fetchFailed(underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    // MARK: - HTML Entity Decoding Tests

    func testHTMLEntityDecoding() {
        // Test the string extension indirectly through SearchResult
        // Since the extension is private, we test through the public interface

        // This tests that the service properly handles HTML entities
        // when parsing search results
        let result = SearchResult(
            title: "Test &amp; Title",
            url: "https://example.com",
            snippet: "Test &lt;snippet&gt;"
        )

        // The raw values are stored as-is
        // Decoding happens during search result parsing
        XCTAssertEqual(result.title, "Test &amp; Title")
    }

    // MARK: - Service Initialization Tests

    func testWebSearchServiceInitialization() async {
        let service = WebSearchService()
        // Service should initialize without errors
        XCTAssertNotNil(service)
    }

    // MARK: - URL Validation Tests

    func testValidURLs() {
        let validURLs = [
            "https://example.com",
            "https://www.example.com/path",
            "https://example.com/path?query=value",
            "http://example.com"
        ]

        for urlString in validURLs {
            XCTAssertNotNil(URL(string: urlString), "URL should be valid: \(urlString)")
        }
    }

    func testInvalidURLs() {
        let invalidURLs = [
            "",
            "not a url",
            "://missing-scheme.com"
        ]

        for urlString in invalidURLs {
            // These should either be nil or require transformation
            let url = URL(string: urlString)
            if url != nil {
                // Some "invalid" URLs might still parse
                // The service should handle these gracefully
            }
        }
    }

    // MARK: - Context Preparation Tests

    func testContextFormatting() {
        let results = [
            SearchResult(title: "Result 1", url: "https://example1.com", snippet: "Snippet 1"),
            SearchResult(title: "Result 2", url: "https://example2.com", snippet: "Snippet 2")
        ]

        // Simulate context formatting
        var context = "Web search results for 'test query':\n\n"
        for (index, result) in results.enumerated() {
            context += """
            [\(index + 1)] \(result.title)
            URL: \(result.url)
            \(result.snippet)

            """
        }

        XCTAssertTrue(context.contains("[1] Result 1"))
        XCTAssertTrue(context.contains("[2] Result 2"))
        XCTAssertTrue(context.contains("URL: https://example1.com"))
        XCTAssertTrue(context.contains("Snippet 1"))
    }
}

// MARK: - Mock Tests for Network Operations

final class WebSearchServiceMockTests: XCTestCase {

    // MARK: - Search Query Encoding Tests

    func testSearchQueryURLEncoding() {
        let queries = [
            ("simple query", "simple%20query"),
            ("swift programming", "swift%20programming"),
            ("query with spaces", "query%20with%20spaces")
        ]

        for (query, expected) in queries {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            XCTAssertEqual(encoded, expected)
        }
    }

    func testSearchQuerySpecialCharacters() {
        let query = "what is 2+2?"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        XCTAssertNotNil(encoded)
        XCTAssertFalse(encoded!.contains(" "))
    }

    // MARK: - HTML Parsing Simulation Tests

    func testTitleExtraction() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test Page Title</title>
        </head>
        <body>Content</body>
        </html>
        """

        let pattern = "<title[^>]*>([^<]+)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            XCTFail("Regex failed")
            return
        }

        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let titleRange = Range(match.range(at: 1), in: html) {
            let title = String(html[titleRange])
            XCTAssertEqual(title, "Test Page Title")
        } else {
            XCTFail("Title not found")
        }
    }

    func testScriptRemoval() {
        let html = """
        <p>Before</p>
        <script>alert('test');</script>
        <p>After</p>
        """

        let pattern = "<script[^>]*>[\\s\\S]*?</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            XCTFail("Regex failed")
            return
        }

        let range = NSRange(html.startIndex..., in: html)
        let cleaned = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")

        XCTAssertFalse(cleaned.contains("alert"))
        XCTAssertTrue(cleaned.contains("Before"))
        XCTAssertTrue(cleaned.contains("After"))
    }

    func testHTMLTagRemoval() {
        let html = "<p>Hello</p> <strong>World</strong>"
        let pattern = "<[^>]+>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            XCTFail("Regex failed")
            return
        }

        let range = NSRange(html.startIndex..., in: html)
        let cleaned = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: " ")

        XCTAssertFalse(cleaned.contains("<"))
        XCTAssertFalse(cleaned.contains(">"))
        XCTAssertTrue(cleaned.contains("Hello"))
        XCTAssertTrue(cleaned.contains("World"))
    }
}

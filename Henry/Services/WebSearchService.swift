import Foundation

// MARK: - Search Models

struct SearchResult: Identifiable, Codable {
    let id: UUID
    let title: String
    let url: String
    let snippet: String

    init(title: String, url: String, snippet: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

struct WebPageContent {
    let url: String
    let title: String
    let content: String
    let fetchedAt: Date

    /// Truncated content for context injection
    func truncated(maxLength: Int = 8000) -> String {
        if content.count <= maxLength {
            return content
        }
        let endIndex = content.index(content.startIndex, offsetBy: maxLength)
        return String(content[..<endIndex]) + "...[truncated]"
    }
}

// MARK: - Errors

enum WebSearchError: LocalizedError {
    case invalidURL
    case fetchFailed(Error)
    case parsingFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .parsingFailed:
            return "Failed to parse content"
        case .noResults:
            return "No results found"
        }
    }
}

// MARK: - Web Search Service

actor WebSearchService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search (using DuckDuckGo HTML)

    func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        // Use DuckDuckGo HTML search
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"

        guard let url = URL(string: urlString) else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.parsingFailed
        }

        return parseSearchResults(html: html, maxResults: maxResults)
    }

    private func parseSearchResults(html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // Simple regex-based parsing for DuckDuckGo HTML results
        let resultPattern = "<a[^>]*class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>"
        let snippetPattern = "<a[^>]*class=\"result__snippet\"[^>]*>([^<]+)</a>"

        guard let resultRegex = try? NSRegularExpression(pattern: resultPattern, options: []),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: []) else {
            return results
        }

        let range = NSRange(html.startIndex..., in: html)

        let resultMatches = resultRegex.matches(in: html, options: [], range: range)
        let snippetMatches = snippetRegex.matches(in: html, options: [], range: range)

        for (index, match) in resultMatches.prefix(maxResults).enumerated() {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            var url = String(html[urlRange])
            let title = String(html[titleRange]).decodingHTMLEntities()

            // DuckDuckGo uses redirect URLs, extract actual URL
            if let actualURL = extractActualURL(from: url) {
                url = actualURL
            }

            var snippet = ""
            if index < snippetMatches.count {
                let snippetMatch = snippetMatches[index]
                if let snippetRange = Range(snippetMatch.range(at: 1), in: html) {
                    snippet = String(html[snippetRange]).decodingHTMLEntities()
                }
            }

            results.append(SearchResult(title: title, url: url, snippet: snippet))
        }

        return results
    }

    private func extractActualURL(from duckduckgoURL: String) -> String? {
        // DuckDuckGo redirect format: //duckduckgo.com/l/?uddg=ENCODED_URL
        if let range = duckduckgoURL.range(of: "uddg=") {
            let encoded = String(duckduckgoURL[range.upperBound...])
            return encoded.removingPercentEncoding
        }
        return duckduckgoURL.hasPrefix("http") ? duckduckgoURL : nil
    }

    // MARK: - Fetch Page Content

    func fetchPageContent(url: String) async throws -> WebPageContent {
        guard let pageURL = URL(string: url) else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: pageURL)
        request.setValue("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.parsingFailed
        }

        let title = extractTitle(from: html)
        let content = extractTextContent(from: html)

        return WebPageContent(
            url: url,
            title: title,
            content: content,
            fetchedAt: Date()
        )
    }

    private func extractTitle(from html: String) -> String {
        let pattern = "<title[^>]*>([^<]+)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return "Untitled"
        }
        return String(html[range]).decodingHTMLEntities()
    }

    private func extractTextContent(from html: String) -> String {
        var text = html

        // Remove script and style tags with content
        let scriptPattern = "<script[^>]*>[\\s\\S]*?</script>"
        let stylePattern = "<style[^>]*>[\\s\\S]*?</style>"

        if let scriptRegex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive) {
            text = scriptRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        if let styleRegex = try? NSRegularExpression(pattern: stylePattern, options: .caseInsensitive) {
            text = styleRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // Remove all HTML tags
        let tagPattern = "<[^>]+>"
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            text = tagRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        // Clean up whitespace
        text = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Decode HTML entities
        text = text.decodingHTMLEntities()

        return text
    }

    // MARK: - Search and Summarize for Claude

    func searchAndPrepareContext(query: String) async throws -> String {
        let results = try await search(query: query)

        if results.isEmpty {
            throw WebSearchError.noResults
        }

        var context = "Web search results for '\(query)':\n\n"

        for (index, result) in results.enumerated() {
            context += """
            [\(index + 1)] \(result.title)
            URL: \(result.url)
            \(result.snippet)

            """
        }

        return context
    }
}

// MARK: - String Extension

private extension String {
    func decodingHTMLEntities() -> String {
        var result = self
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#x27;": "'",
            "&#x2F;": "/",
            "&#32;": " "
        ]

        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        return result
    }
}

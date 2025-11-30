import Foundation
@testable import Henry

// MARK: - Mock Configuration

/// Mock configuration for testing purposes
/// This provides fake API keys for unit tests that don't make real API calls
enum MockConfig {
    static let testAPIKey = "test-api-key-for-unit-tests"
}

// MARK: - Mock Services

/// Mock Anthropic service for testing
class MockAnthropicService {
    var shouldFail = false
    var mockResponse = "Mock response from Claude"
    var mockError: Error?
    var callCount = 0
    var lastMessages: [APIMessage] = []

    func mockStreamMessage(
        messages: [APIMessage],
        model: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        callCount += 1
        lastMessages = messages

        return AsyncThrowingStream { continuation in
            if self.shouldFail, let error = self.mockError {
                continuation.yield(.error(error))
                continuation.finish(throwing: error)
                return
            }

            continuation.yield(.messageStart)

            // Simulate streaming text
            for char in self.mockResponse {
                continuation.yield(.text(String(char)))
            }

            continuation.yield(.messageEnd)
            continuation.finish()
        }
    }
}

/// Mock Web Search service for testing
class MockWebSearchService {
    var shouldFail = false
    var mockResults: [SearchResult] = []
    var mockError: Error?
    var searchCallCount = 0
    var lastQuery: String?

    func mockSearch(query: String, maxResults: Int) async throws -> [SearchResult] {
        searchCallCount += 1
        lastQuery = query

        if shouldFail {
            throw mockError ?? WebSearchError.noResults
        }

        return Array(mockResults.prefix(maxResults))
    }

    func mockFetchPageContent(url: String) async throws -> WebPageContent {
        if shouldFail {
            throw mockError ?? WebSearchError.invalidURL
        }

        return WebPageContent(
            url: url,
            title: "Mock Page",
            content: "Mock page content for \(url)",
            fetchedAt: Date()
        )
    }
}

// MARK: - Test Doubles

/// Spy for tracking method calls
class MethodCallSpy {
    private var calls: [String: [(arguments: [Any], timestamp: Date)]] = [:]

    func record(_ method: String, arguments: [Any] = []) {
        if calls[method] == nil {
            calls[method] = []
        }
        calls[method]?.append((arguments: arguments, timestamp: Date()))
    }

    func callCount(for method: String) -> Int {
        calls[method]?.count ?? 0
    }

    func wasCalled(_ method: String) -> Bool {
        callCount(for: method) > 0
    }

    func lastCall(for method: String) -> (arguments: [Any], timestamp: Date)? {
        calls[method]?.last
    }

    func reset() {
        calls.removeAll()
    }
}

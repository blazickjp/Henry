import Foundation

// MARK: - API Models

struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [APIMessage]
    let stream: Bool
    let tools: [Tool]?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
        case tools
    }
}

/// Simple text-only message
struct APIMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Multimodal Content Types

/// Content block for multimodal messages
enum APIContentBlock {
    case text(String)
    case image(mediaType: String, base64Data: String)

    var dictionary: [String: Any] {
        switch self {
        case .text(let text):
            return ["type": "text", "text": text]
        case .image(let mediaType, let base64Data):
            return [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType,
                    "data": base64Data
                ]
            ]
        }
    }
}

/// Multimodal message with text and/or images
struct APIMultimodalMessage {
    let role: String
    let content: [APIContentBlock]

    var dictionary: [String: Any] {
        [
            "role": role,
            "content": content.map { $0.dictionary }
        ]
    }
}

struct Tool: Codable {
    let name: String
    let description: String
    let inputSchema: InputSchema

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

struct InputSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]
}

struct PropertySchema: Codable {
    let type: String
    let description: String
}

// MARK: - Streaming Event Types

enum StreamEvent {
    case text(String)
    case toolUse(name: String, input: [String: Any])
    case messageStart
    case messageEnd
    case error(Error)
}

// MARK: - Service Errors

enum AnthropicError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Anthropic Service

actor AnthropicService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    static let defaultModel = "claude-sonnet-4-20250514"
    static let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229"
    ]

    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? Config.anthropicAPIKey
    }

    // MARK: - Streaming Request

    func streamMessage(
        messages: [APIMessage],
        model: String = defaultModel,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096,
        enableTools: Bool = false
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performStreamRequest(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        enableTools: enableTools,
                        continuation: continuation
                    )
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Multimodal Streaming Request

    func streamMultimodalMessage(
        messages: [[String: Any]],
        model: String = defaultModel,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performMultimodalStreamRequest(
                        messages: messages,
                        model: model,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        continuation: continuation
                    )
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func performMultimodalStreamRequest(
        messages: [[String: Any]],
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        // Build request body manually for multimodal
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages,
            "stream": true
        ]

        if let system = systemPrompt ?? defaultSystemPrompt as String? {
            body["system"] = system
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AnthropicError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        continuation.yield(.messageStart)

        var buffer = ""
        for try await line in bytes.lines {
            buffer += line + "\n"

            while let eventEnd = buffer.range(of: "\n\n") {
                let eventData = String(buffer[..<eventEnd.lowerBound])
                buffer = String(buffer[eventEnd.upperBound...])

                if let event = parseSSEEvent(eventData) {
                    continuation.yield(event)

                    if case .messageEnd = event {
                        continuation.finish()
                        return
                    }
                }
            }
        }

        continuation.yield(.messageEnd)
        continuation.finish()
    }

    private func performStreamRequest(
        messages: [APIMessage],
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        enableTools: Bool,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let tools: [Tool]? = enableTools ? buildTools() : nil

        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: maxTokens,
            system: systemPrompt ?? defaultSystemPrompt,
            messages: messages,
            stream: true,
            tools: tools
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AnthropicError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        continuation.yield(.messageStart)

        var buffer = ""
        for try await line in bytes.lines {
            buffer += line + "\n"

            // Process complete SSE events
            while let eventEnd = buffer.range(of: "\n\n") {
                let eventData = String(buffer[..<eventEnd.lowerBound])
                buffer = String(buffer[eventEnd.upperBound...])

                if let event = parseSSEEvent(eventData) {
                    continuation.yield(event)

                    if case .messageEnd = event {
                        continuation.finish()
                        return
                    }
                }
            }
        }

        continuation.yield(.messageEnd)
        continuation.finish()
    }

    // MARK: - Non-Streaming Request

    func sendMessage(
        messages: [APIMessage],
        model: String = defaultModel,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096
    ) async throws -> String {
        var fullResponse = ""

        for try await event in streamMessage(
            messages: messages,
            model: model,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        ) {
            if case .text(let text) = event {
                fullResponse += text
            }
        }

        return fullResponse
    }

    // MARK: - SSE Parsing

    private func parseSSEEvent(_ eventString: String) -> StreamEvent? {
        let lines = eventString.components(separatedBy: "\n")

        var eventType: String?
        var dataString: String?

        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                dataString = String(line.dropFirst(6))
            }
        }

        guard let data = dataString, let jsonData = data.data(using: .utf8) else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        switch eventType {
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any],
               let deltaType = delta["type"] as? String {
                if deltaType == "text_delta", let text = delta["text"] as? String {
                    return .text(text)
                } else if deltaType == "input_json_delta", let partialJson = delta["partial_json"] as? String {
                    return .text(partialJson) // Tool input streaming
                }
            }

        case "content_block_start":
            if let contentBlock = json["content_block"] as? [String: Any],
               let blockType = contentBlock["type"] as? String,
               blockType == "tool_use",
               let name = contentBlock["name"] as? String {
                return .toolUse(name: name, input: [:])
            }

        case "message_stop":
            return .messageEnd

        case "message_delta":
            if let delta = json["delta"] as? [String: Any],
               let _ = delta["stop_reason"] as? String {
                return .messageEnd
            }

        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return .error(AnthropicError.apiError(message))
            }

        default:
            break
        }

        return nil
    }

    // MARK: - Tools

    private func buildTools() -> [Tool] {
        [
            Tool(
                name: "web_search",
                description: "Search the web for current information. Use this when you need up-to-date information or facts you're not sure about.",
                inputSchema: InputSchema(
                    type: "object",
                    properties: [
                        "query": PropertySchema(
                            type: "string",
                            description: "The search query"
                        )
                    ],
                    required: ["query"]
                )
            )
        ]
    }

    // MARK: - System Prompt

    private var defaultSystemPrompt: String {
        """
        You are Claude, an AI assistant created by Anthropic. You are helpful, harmless, and honest.

        When writing code, always use markdown code blocks with the appropriate language identifier.
        For example: ```swift, ```python, ```html, etc.

        When creating visual content like diagrams, use mermaid code blocks.
        When sharing HTML content that should be rendered, use ```html code blocks.

        Be concise but thorough. Break down complex topics into understandable parts.
        """
    }
}

// MARK: - Convenience Extensions

extension AnthropicService {
    /// Convert Message models to API format (text only)
    static func convertMessages(_ messages: [Message]) -> [APIMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }.map { message in
            APIMessage(role: message.role.rawValue, content: message.content)
        }
    }

    /// Convert Message models to multimodal API format (with images)
    static func convertMessagesMultimodal(_ messages: [Message]) -> [[String: Any]] {
        messages.sorted { $0.timestamp < $1.timestamp }.map { message in
            if message.hasImages {
                return message.apiFormatMultimodal
            } else {
                // Text-only messages can use simple format
                return [
                    "role": message.role.rawValue,
                    "content": message.content
                ]
            }
        }
    }

    /// Check if any messages contain images
    static func hasMultimodalContent(_ messages: [Message]) -> Bool {
        messages.contains { $0.hasImages }
    }
}

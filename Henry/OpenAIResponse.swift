import Foundation

struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let usage: Usage
    let choices: [Choice]

    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct Choice: Codable {
        let message: Message
        let logprobs: String?
        let finishReason: String
        let index: Int

        enum CodingKeys: String, CodingKey {
            case message
            case logprobs
            case finishReason = "finish_reason"
            case index
        }

        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}
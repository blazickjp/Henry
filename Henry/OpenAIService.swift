import Foundation
import HTTPTypes
import HTTPTypesFoundation

class OpenAIService {
    private let apiKey: String

    init() {
        self.apiKey = Config.openAIAPIKey
    }
    
    
    /**
     Fetches a response from the OpenAI API.

     Args:
         completion (Result<String, Error> -> Void): The completion handler to call when the request is complete.
     */
    func fetchResponse(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON Data:", jsonString)
            } else {
                print("Failed to convert JSON data to string")
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "DataError", code: -1, userInfo: nil)))
                    return
                }

                do {
                    let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    let responseText = openAIResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No response"
                    completion(.success(responseText))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}

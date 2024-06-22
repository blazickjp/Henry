import Foundation
import CoreLocation

class AnthropicService {
    private let apiKey: String
    private let locationService: LocationService
    
    init(locationService: LocationService) {
        self.apiKey = Config.anthropicAPIKey
        self.locationService = locationService
    }
    
    func fetchResponseWithTimeAndLocation(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let currentTime = dateFormatter.string(from: Date())

        let systemMessageContent: String
        if let location = locationService.currentLocation {
            systemMessageContent = "The user's current location is \(location.coordinate.latitude), \(location.coordinate.longitude) and the current time is \(currentTime)."
        } else {
            systemMessageContent = "The user's location is not available, but the current time is \(currentTime)."
        }

        fetchResponse(messages: messages, systemMessage: systemMessageContent, completion: completion)
    }
    
    func fetchResponse(messages: [[String: String]], systemMessage: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key") // Do not include Bearer in the API key
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20240620",
            "messages": messages,
            "system": systemMessage,
            "max_tokens": 1000,
            "stream": true
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                self.handleStreamingResponse(data: data, completion: completion)
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handleStreamingResponse(data: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let dataString = String(data: data, encoding: .utf8) else {
            completion(.failure(NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response data"])))
            return
        }
        
        let events = dataString.components(separatedBy: "\n\n")
        var fullResponse = ""
        
        for event in events {
            let eventLines = event.components(separatedBy: "\n")
            guard eventLines.count >= 2 else { continue }
            
            let eventType = eventLines[0].replacingOccurrences(of: "event: ", with: "")
            let dataLine = eventLines[1].replacingOccurrences(of: "data: ", with: "")
            
            guard let jsonData = dataLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
                continue
            }
            
            switch eventType {
            case "content_block_start":
                if let contentBlock = json["content_block"] as? [String: Any],
                   contentBlock["type"] as? String == "text" {
                    // Initialize text content if needed
                }
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String,
                   deltaType == "text_delta",
                   let text = delta["text"] as? String {
                    fullResponse += text
                }
            case "message_delta":
                if let delta = json["delta"] as? [String: Any],
                   let stopReason = delta["stop_reason"] as? String,
                   stopReason == "end_turn" {
                    completion(.success(fullResponse))
                    return
                }
            case "message_stop":
                completion(.success(fullResponse))
                return
            default:
                break
            }
        }
        
        if fullResponse.isEmpty {
            completion(.failure(NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
        } else {
            completion(.success(fullResponse))
        }
    }
}

import SwiftUI

class AppMenuViewModel: ObservableObject {
    @Published var responseText: String = "Press the button to get a response"
    @Published var isLoading: Bool = false
    @Published var userInput: String = ""
    private let openAIService = OpenAIService()

    func fetchResponse() {
        guard !userInput.isEmpty else {
            responseText = "Input is empty"
            return
        }

        let messages = [["role": "user", "content": userInput]]
        isLoading = true
        openAIService.fetchResponse(messages: messages) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    self?.responseText = response
                case .failure(let error):
                    self?.responseText = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    func fetchResponseWithClipboardContent() {
        if let clipboardContent = readFromClipboard() {
            let messages = [["role": "user", "content": clipboardContent]]
            isLoading = true
            openAIService.fetchResponse(messages: messages) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    switch result {
                    case .success(let response):
                        self?.responseText = response
                    case .failure(let error):
                        self?.responseText = "Error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            responseText = "No clipboard content available"
        }
    }
    
    private func readFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
}
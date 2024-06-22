import SwiftUI

class AppMenuViewModel: ObservableObject {
    @Published var responseText: String = "Press the button to get a response"
    @Published var isLoading: Bool = false
    @Published var userInput: String = ""
    private let anthropicService: AnthropicService
    private let locationService: LocationService
    
    init() {
        self.locationService = LocationService()
        self.anthropicService = AnthropicService(locationService: locationService)
        locationService.startUpdatingLocation()
    }
    
    func fetchResponse() {
        guard !userInput.isEmpty else {
            responseText = "Input is empty"
            return
        }
        
        let messages = [["role": "user", "content": userInput]]
        isLoading = true
        anthropicService.fetchResponseWithTimeAndLocation(messages: messages) { [weak self] result in
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
}

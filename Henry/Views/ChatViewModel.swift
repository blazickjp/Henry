import Foundation
import SwiftUI
import SwiftData
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published State

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var streamingText: String = ""
    @Published var errorMessage: String?
    @Published var selectedArtifact: Artifact?
    @Published var showArtifactPanel: Bool = false

    // MARK: - Annotation State

    @Published var showAnnotationView: Bool = false
    @Published var annotationSourceImage: UIImage?
    @Published var messageToAnnotate: Message?

    // MARK: - Dependencies

    private let anthropicService: AnthropicService
    private let webSearchService: WebSearchService
    private var modelContext: ModelContext?

    // MARK: - Current Conversation

    var currentConversation: Conversation?

    // MARK: - Settings

    var selectedModel: String = AnthropicService.defaultModel

    init() {
        self.anthropicService = AnthropicService()
        self.webSearchService = WebSearchService()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isLoading else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil
        streamingText = ""

        // Create or get conversation
        let conversation: Conversation
        if let existing = currentConversation {
            conversation = existing
        } else {
            conversation = Conversation()
            currentConversation = conversation
            modelContext?.insert(conversation)
        }

        // Add user message
        let userMessage = Message(role: .user, content: text)
        conversation.addMessage(userMessage)

        do {
            try modelContext?.save()
        } catch {
            print("Failed to save user message: \(error)")
        }

        // Prepare messages for API
        let apiMessages = AnthropicService.convertMessages(conversation.messages)

        // Stream response
        do {
            var fullResponse = ""

            for try await event in await anthropicService.streamMessage(
                messages: apiMessages,
                model: selectedModel,
                systemPrompt: conversation.systemPrompt,
                maxTokens: 4096
            ) {
                switch event {
                case .text(let text):
                    fullResponse += text
                    streamingText = fullResponse

                case .messageEnd:
                    // Create assistant message
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    assistantMessage.extractArtifacts()
                    conversation.addMessage(assistantMessage)

                    do {
                        try modelContext?.save()
                    } catch {
                        print("Failed to save assistant message: \(error)")
                    }

                    streamingText = ""

                case .error(let error):
                    errorMessage = error.localizedDescription

                default:
                    break
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Send Message with Image (Annotation)

    func sendAnnotatedMessage(image: UIImage, text: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        streamingText = ""

        // Create or get conversation
        let conversation: Conversation
        if let existing = currentConversation {
            conversation = existing
        } else {
            conversation = Conversation()
            currentConversation = conversation
            modelContext?.insert(conversation)
        }

        // Add user message with image
        let userMessage = Message(role: .user, content: text, uiImages: [image])
        conversation.addMessage(userMessage)

        do {
            try modelContext?.save()
        } catch {
            print("Failed to save user message: \(error)")
        }

        // Use multimodal API for messages with images
        let apiMessages = AnthropicService.convertMessagesMultimodal(conversation.messages)

        // Stream response
        do {
            var fullResponse = ""

            for try await event in await anthropicService.streamMultimodalMessage(
                messages: apiMessages,
                model: selectedModel,
                systemPrompt: conversation.systemPrompt ?? annotationSystemPrompt,
                maxTokens: 4096
            ) {
                switch event {
                case .text(let text):
                    fullResponse += text
                    streamingText = fullResponse

                case .messageEnd:
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    assistantMessage.extractArtifacts()
                    conversation.addMessage(assistantMessage)

                    do {
                        try modelContext?.save()
                    } catch {
                        print("Failed to save assistant message: \(error)")
                    }

                    streamingText = ""

                case .error(let error):
                    errorMessage = error.localizedDescription

                default:
                    break
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// System prompt optimized for analyzing annotated images
    private var annotationSystemPrompt: String {
        """
        You are Claude, an AI assistant with vision capabilities. The user is sharing annotated images with you - they have drawn or marked up content using an Apple Pencil to highlight specific areas or add visual notes.

        When analyzing annotated images:
        1. Pay close attention to any drawn markings, circles, arrows, or highlights
        2. The annotations indicate what the user wants you to focus on
        3. Describe what you see in the annotated areas
        4. Answer questions about the highlighted content
        5. If code is shown, analyze the highlighted portions

        Be helpful and specific about the annotated content.
        """
    }

    // MARK: - Annotation Helpers

    func startAnnotation(for message: Message, with image: UIImage) {
        messageToAnnotate = message
        annotationSourceImage = image
        showAnnotationView = true
    }

    func cancelAnnotation() {
        showAnnotationView = false
        annotationSourceImage = nil
        messageToAnnotate = nil
    }

    // MARK: - New Conversation

    func newConversation() {
        currentConversation = nil
        inputText = ""
        streamingText = ""
        errorMessage = nil
        showArtifactPanel = false
        selectedArtifact = nil
    }

    // MARK: - Load Conversation

    func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
        inputText = ""
        streamingText = ""
        errorMessage = nil
        showArtifactPanel = false
        selectedArtifact = nil
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ conversation: Conversation) {
        if currentConversation?.id == conversation.id {
            newConversation()
        }
        modelContext?.delete(conversation)
        do {
            try modelContext?.save()
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }

    // MARK: - Artifact Handling

    func selectArtifact(_ artifact: Artifact) {
        selectedArtifact = artifact
        showArtifactPanel = true
    }

    func closeArtifactPanel() {
        showArtifactPanel = false
        selectedArtifact = nil
    }

    // MARK: - Web Search

    func performWebSearch(query: String) async -> String? {
        do {
            let context = try await webSearchService.searchAndPrepareContext(query: query)
            return context
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Helpers

    var displayMessages: [Message] {
        currentConversation?.messages.sorted { $0.timestamp < $1.timestamp } ?? []
    }

    var hasMessages: Bool {
        !(currentConversation?.messages.isEmpty ?? true)
    }
}

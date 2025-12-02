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
    @Published var enableWebSearch: Bool = UserDefaults.standard.bool(forKey: "enableWebSearch")
    @Published var isSearching: Bool = false

    init() {
        self.anthropicService = AnthropicService()
        self.webSearchService = WebSearchService()
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "enableWebSearch") == nil {
            enableWebSearch = true
        }
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

        // Stream response with potential tool use
        await streamWithToolSupport(
            apiMessages: apiMessages,
            conversation: conversation
        )

        isLoading = false
        isSearching = false
        print("[ChatViewModel] sendMessage completed")
    }

    /// Stream response with tool use support
    private func streamWithToolSupport(
        apiMessages: [APIMessage],
        conversation: Conversation
    ) async {
        // Refresh enableWebSearch from UserDefaults
        enableWebSearch = UserDefaults.standard.bool(forKey: "enableWebSearch")

        do {
            var fullResponse = ""
            var pendingToolUse: (id: String, name: String, input: [String: Any])?

            print("[ChatViewModel] Starting stream request with \(apiMessages.count) messages")
            print("[ChatViewModel] Using model: \(selectedModel), enableTools: \(enableWebSearch)")

            for try await event in await anthropicService.streamMessage(
                messages: apiMessages,
                model: selectedModel,
                systemPrompt: conversation.systemPrompt,
                maxTokens: 4096,
                enableTools: enableWebSearch
            ) {
                switch event {
                case .text(let text):
                    fullResponse += text
                    streamingText = fullResponse
                    print("[ChatViewModel] Received text chunk: \(text.prefix(50))...")

                case .toolUse(let id, let name, let input):
                    print("[ChatViewModel] Tool use requested: \(name), id: \(id), input: \(input)")
                    pendingToolUse = (id, name, input)

                case .messageEnd:
                    print("[ChatViewModel] Message complete. Full response length: \(fullResponse.count)")

                    // If we have a pending tool use, execute it and continue
                    if let toolUse = pendingToolUse {
                        // Save partial assistant response if any
                        if !fullResponse.isEmpty {
                            let partialMessage = Message(role: .assistant, content: fullResponse)
                            conversation.addMessage(partialMessage)
                            try? modelContext?.save()
                        }

                        // Execute the tool
                        await executeToolAndContinue(
                            toolUse: toolUse,
                            conversation: conversation,
                            previousResponse: fullResponse
                        )
                        return
                    }

                    // No tool use - save the final response
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    assistantMessage.extractArtifacts()
                    conversation.addMessage(assistantMessage)

                    do {
                        try modelContext?.save()
                    } catch {
                        print("[ChatViewModel] Failed to save assistant message: \(error)")
                    }

                    streamingText = ""

                case .error(let error):
                    print("[ChatViewModel] Stream error: \(error)")
                    errorMessage = error.localizedDescription

                case .messageStart:
                    break
                }
            }
            print("[ChatViewModel] Stream loop finished")
        } catch {
            print("[ChatViewModel] Caught error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Execute a tool and continue the conversation with the result
    private func executeToolAndContinue(
        toolUse: (id: String, name: String, input: [String: Any]),
        conversation: Conversation,
        previousResponse: String
    ) async {
        print("[ChatViewModel] Executing tool: \(toolUse.name)")

        var toolResult: String = ""

        switch toolUse.name {
        case "web_search":
            if let query = toolUse.input["query"] as? String {
                isSearching = true
                streamingText = "🔍 Searching: \(query)..."

                if let result = await performWebSearch(query: query) {
                    toolResult = result
                } else {
                    toolResult = "Search failed. Unable to retrieve results."
                }
                isSearching = false
            } else {
                toolResult = "Error: No search query provided"
            }

        default:
            toolResult = "Unknown tool: \(toolUse.name)"
        }

        print("[ChatViewModel] Tool result length: \(toolResult.count)")

        // Build messages for continuation with tool result
        // Format: previous messages + assistant tool_use + user tool_result
        var messagesWithToolResult: [[String: Any]] = []

        // Add all previous messages
        for msg in conversation.messages.sorted(by: { $0.timestamp < $1.timestamp }) {
            messagesWithToolResult.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        // Add assistant message with tool use
        messagesWithToolResult.append([
            "role": "assistant",
            "content": [
                [
                    "type": "tool_use",
                    "id": toolUse.id,
                    "name": toolUse.name,
                    "input": toolUse.input
                ]
            ]
        ])

        // Add user message with tool result
        messagesWithToolResult.append([
            "role": "user",
            "content": [
                [
                    "type": "tool_result",
                    "tool_use_id": toolUse.id,
                    "content": toolResult
                ]
            ]
        ])

        // Continue streaming with tool result
        await streamToolResultResponse(
            messages: messagesWithToolResult,
            conversation: conversation
        )
    }

    /// Stream the response after providing tool results
    private func streamToolResultResponse(
        messages: [[String: Any]],
        conversation: Conversation
    ) async {
        do {
            var fullResponse = ""
            streamingText = ""

            for try await event in await anthropicService.streamMessageWithToolResult(
                messages: messages,
                model: selectedModel,
                systemPrompt: conversation.systemPrompt,
                maxTokens: 4096,
                enableTools: enableWebSearch
            ) {
                switch event {
                case .text(let text):
                    fullResponse += text
                    streamingText = fullResponse

                case .toolUse(let id, let name, let input):
                    // Handle nested tool use (Claude wants to search again)
                    print("[ChatViewModel] Nested tool use: \(name)")
                    if !fullResponse.isEmpty {
                        let partialMessage = Message(role: .assistant, content: fullResponse)
                        conversation.addMessage(partialMessage)
                        try? modelContext?.save()
                    }

                    await executeToolAndContinue(
                        toolUse: (id, name, input),
                        conversation: conversation,
                        previousResponse: fullResponse
                    )
                    return

                case .messageEnd:
                    // Save the final response
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    assistantMessage.extractArtifacts()
                    conversation.addMessage(assistantMessage)

                    do {
                        try modelContext?.save()
                    } catch {
                        print("[ChatViewModel] Failed to save final assistant message: \(error)")
                    }

                    streamingText = ""

                case .error(let error):
                    errorMessage = error.localizedDescription

                case .messageStart:
                    break
                }
            }
        } catch {
            print("[ChatViewModel] Tool result stream error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send Message with Image (Annotation)

    func sendAnnotatedMessage(image: UIImage, text: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        streamingText = ""

        // Validate and normalize text input
        // If text is empty or whitespace-only, provide a default prompt
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageText = trimmedText.isEmpty ? "What do you see in this image?" : trimmedText

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
        let userMessage = Message(role: .user, content: messageText, uiImages: [image])
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

    // MARK: - Regenerate Response

    func regenerateResponse(for message: Message) async {
        guard let conversation = currentConversation else { return }
        guard message.role == .assistant else { return }
        guard !isLoading else { return }

        // Get all messages sorted by timestamp
        let sortedMessages = conversation.messages.sorted { $0.timestamp < $1.timestamp }

        // Find the index of this message
        guard let messageIndex = sortedMessages.firstIndex(where: { $0.id == message.id }) else { return }

        // Delete this message and all messages after it
        let messagesToDelete = sortedMessages[messageIndex...]
        for msg in messagesToDelete {
            conversation.messages.removeAll { $0.id == msg.id }
            modelContext?.delete(msg)
        }

        do {
            try modelContext?.save()
        } catch {
            print("Failed to delete messages for regeneration: \(error)")
        }

        // Now regenerate - prepare messages for API (remaining messages)
        isLoading = true
        errorMessage = nil
        streamingText = ""

        let apiMessages = AnthropicService.convertMessages(conversation.messages)

        // Stream new response
        do {
            var fullResponse = ""
            print("[ChatViewModel] Regenerating response with \(apiMessages.count) messages")

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
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    assistantMessage.extractArtifacts()
                    conversation.addMessage(assistantMessage)

                    do {
                        try modelContext?.save()
                    } catch {
                        print("Failed to save regenerated message: \(error)")
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

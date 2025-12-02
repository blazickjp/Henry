import SwiftUI
import MarkdownUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main Chat Area
                chatArea
                    .frame(width: viewModel.showArtifactPanel ? geometry.size.width * 0.55 : geometry.size.width)

                // Artifact Panel
                if viewModel.showArtifactPanel, let artifact = viewModel.selectedArtifact {
                    Divider()

                    ArtifactView(artifact: artifact, onClose: {
                        viewModel.closeArtifactPanel()
                    })
                    .frame(width: geometry.size.width * 0.45)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.showArtifactPanel)
        }
        .background(Color.backgroundPrimary)
        .sheet(isPresented: $viewModel.showAnnotationView) {
            if let image = viewModel.annotationSourceImage {
                AnnotationView(
                    isPresented: $viewModel.showAnnotationView,
                    contentToAnnotate: image,
                    onSend: { annotatedImage, message in
                        Task {
                            await viewModel.sendAnnotatedMessage(image: annotatedImage, text: message)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        VStack(spacing: 0) {
            // Messages
            if viewModel.hasMessages || !viewModel.streamingText.isEmpty {
                messagesScrollView
            } else {
                emptyStateView
            }

            // Error Banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            // Input Area
            inputArea
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(.claudeOrange)

            Text("Henry")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Powered by Claude")
                .font(.title3)
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                featureRow(icon: "doc.text", text: "Create and preview code artifacts")
                featureRow(icon: "globe", text: "Search the web for information")
                featureRow(icon: "pencil.tip.crop.circle", text: "Annotate with Apple Pencil")
                featureRow(icon: "bubble.left.and.bubble.right", text: "Have natural conversations")
            }
            .padding(.top, Spacing.lg)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.claudeOrange)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.displayMessages) { message in
                        MessageBubble(
                            message: message,
                            onArtifactTap: { artifact in
                                viewModel.selectArtifact(artifact)
                            },
                            onAnnotate: { message, image in
                                viewModel.startAnnotation(for: message, with: image)
                            }
                        )
                        .id(message.id)
                    }

                    // Streaming message
                    if !viewModel.streamingText.isEmpty {
                        streamingBubble
                    }

                    // Loading indicator
                    if viewModel.isLoading && viewModel.streamingText.isEmpty {
                        loadingIndicator
                    }

                    // Scroll anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.displayMessages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Markdown(viewModel.streamingText)
                    .markdownTheme(.claude)

                HStack(spacing: Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .chatBubble(isUser: false)
            .frame(maxWidth: 600, alignment: .leading)

            Spacer(minLength: 60)
        }
    }

    private var loadingIndicator: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                Text("Thinking...")
                    .foregroundColor(.textSecondary)
            }
            .chatBubble(isUser: false)

            Spacer()
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)

            Spacer()

            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: Spacing.md) {
                // Text Input
                TextField("Message Henry...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.chatInput)
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !viewModel.inputText.isEmpty {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                    }
                    .submitLabel(.send)

                // Send Button
                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: viewModel.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.inputText.isEmpty && !viewModel.isLoading ? .textSecondary : .claudeOrange)
                }
                .disabled(viewModel.inputText.isEmpty && !viewModel.isLoading)
            }
            .padding()
            .background(Color.backgroundSecondary)
        }
    }
}

// MARK: - Markdown Theme

extension MarkdownUI.Theme {
    static let claude = Theme()
        .text {
            ForegroundColor(.textPrimary)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color.codeBackground)
            ForegroundColor(Color.codeText)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                        ForegroundColor(Color.codeText)
                    }
                    .padding()
            }
            .background(Color.codeBackground)
            .cornerRadius(Spacing.sm)
        }
        .link {
            ForegroundColor(.claudeOrange)
        }
        .strong {
            FontWeight(.semibold)
        }
}

// MARK: - Preview

#Preview {
    ChatView(viewModel: ChatViewModel())
}

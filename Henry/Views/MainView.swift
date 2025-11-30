import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @StateObject private var viewModel = ChatViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            ChatView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(selectedModel: $viewModel.selectedModel)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chats")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.title2)
                }
                .buttonStyle(IconButtonStyle())
            }
            .padding()

            // New Chat Button
            Button {
                viewModel.newConversation()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Chat")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, Spacing.md)

            Divider()

            // Conversation List
            if conversations.isEmpty {
                emptyStateView
            } else {
                conversationList
            }
        }
        .background(Color.sidebarBackground)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary)

            Text("No conversations yet")
                .font(.headline)
                .foregroundColor(.textSecondary)

            Text("Start a new chat to begin")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var conversationList: some View {
        List(selection: Binding(
            get: { viewModel.currentConversation?.id },
            set: { id in
                if let id = id, let conversation = conversations.first(where: { $0.id == id }) {
                    viewModel.loadConversation(conversation)
                }
            }
        )) {
            ForEach(conversations) { conversation in
                ConversationRow(conversation: conversation)
                    .tag(conversation.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(conversation.title)
                .font(.sidebarTitle)
                .lineLimit(1)
                .foregroundColor(.textPrimary)

            HStack {
                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(conversation.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .modelContainer(for: [Conversation.self, Message.self, Artifact.self], inMemory: true)
}

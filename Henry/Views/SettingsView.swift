import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: String

    @AppStorage("customSystemPrompt") private var customSystemPrompt: String = ""
    @AppStorage("enableWebSearch") private var enableWebSearch: Bool = true
    @AppStorage("maxTokens") private var maxTokens: Int = 4096

    var body: some View {
        NavigationStack {
            Form {
                // Model Selection
                modelSection

                // Response Settings
                responseSection

                // System Prompt
                systemPromptSection

                // Features
                featuresSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            Picker("Model", selection: $selectedModel) {
                ForEach(AnthropicService.availableModels, id: \.self) { model in
                    Text(modelDisplayName(model))
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("AI Model")
        } footer: {
            Text(modelDescription(selectedModel))
        }
    }

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "claude-sonnet-4-20250514":
            return "Claude Sonnet 4"
        case "claude-3-5-sonnet-20241022":
            return "Claude 3.5 Sonnet"
        case "claude-3-5-haiku-20241022":
            return "Claude 3.5 Haiku"
        case "claude-3-opus-20240229":
            return "Claude 3 Opus"
        default:
            return model
        }
    }

    private func modelDescription(_ model: String) -> String {
        switch model {
        case "claude-sonnet-4-20250514":
            return "Latest balanced model with excellent reasoning and speed"
        case "claude-3-5-sonnet-20241022":
            return "Previous generation balanced model"
        case "claude-3-5-haiku-20241022":
            return "Fast and efficient for simple tasks"
        case "claude-3-opus-20240229":
            return "Most capable model for complex tasks"
        default:
            return ""
        }
    }

    // MARK: - Response Section

    private var responseSection: some View {
        Section {
            Picker("Max Response Length", selection: $maxTokens) {
                Text("Short (1K)").tag(1024)
                Text("Medium (2K)").tag(2048)
                Text("Long (4K)").tag(4096)
                Text("Very Long (8K)").tag(8192)
            }
            .pickerStyle(.menu)
        } header: {
            Text("Response Settings")
        } footer: {
            Text("Longer responses use more tokens and may take longer to generate.")
        }
    }

    // MARK: - System Prompt Section

    private var systemPromptSection: some View {
        Section {
            TextEditor(text: $customSystemPrompt)
                .frame(minHeight: 100)
                .font(.body)

            if !customSystemPrompt.isEmpty {
                Button("Clear Custom Prompt", role: .destructive) {
                    customSystemPrompt = ""
                }
            }
        } header: {
            Text("Custom System Prompt")
        } footer: {
            Text("Add custom instructions that will be included with every message. Leave empty to use the default.")
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        Section {
            Toggle("Web Search", isOn: $enableWebSearch)
        } header: {
            Text("Features")
        } footer: {
            Text("Allow Claude to search the web for current information when needed.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.textSecondary)
            }

            HStack {
                Text("Powered by")
                Spacer()
                Text("Anthropic Claude API")
                    .foregroundColor(.textSecondary)
            }

            Link(destination: URL(string: "https://docs.anthropic.com")!) {
                HStack {
                    Text("API Documentation")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.textSecondary)
                }
            }

            Link(destination: URL(string: "https://console.anthropic.com")!) {
                HStack {
                    Text("Anthropic Console")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.textSecondary)
                }
            }
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView(selectedModel: .constant(AnthropicService.defaultModel))
}

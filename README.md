# Henry - AI Chat for iPad

Henry is a powerful iPad chat application powered by Anthropic's Claude API. It provides a ChatGPT-like experience with unique Anthropic features including **Artifacts** for code/HTML preview and **Web Browsing** capabilities.

## Features

### Chat Interface
- **Real-time Streaming**: Watch Claude's responses appear in real-time with smooth streaming
- **Conversation History**: All chats are saved locally using SwiftData
- **Multi-conversation Support**: Manage multiple chat threads with a sidebar interface
- **Markdown Rendering**: Rich text formatting with code syntax highlighting

### Artifacts (Claude-style)
- **Code Artifacts**: Extracted code blocks displayed as interactive artifacts
- **HTML Preview**: Live rendering of HTML content in a sandboxed WebView
- **React Components**: Preview React/JSX components with live rendering
- **SVG Images**: View SVG graphics directly in the app
- **Mermaid Diagrams**: Render flowcharts and diagrams from Mermaid syntax
- **Copy & Share**: Easily copy code or share artifacts

### Web Browsing
- **Built-in Browser**: Full-featured in-app web browser
- **Web Search**: DuckDuckGo-powered search integration
- **Send to Chat**: Extract web content and discuss it with Claude

### Customization
- **Model Selection**: Choose between Claude models (Sonnet 4, 3.5 Sonnet, Haiku, Opus)
- **Custom System Prompts**: Personalize Claude's behavior
- **Response Length Control**: Adjust max tokens for responses
- **Dark/Light Mode**: Automatic theme based on system settings

## Screenshots

*Coming soon*

## Requirements

- **iPad**: iOS 17.0+ / iPadOS 17.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Anthropic API Key**: Get one at [console.anthropic.com](https://console.anthropic.com)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Henry.git
cd Henry
```

### 2. Configure API Key

```bash
# Copy the example config
cp Henry/Config.example.swift Henry/Config.swift

# Edit Config.swift and add your Anthropic API key
```

```swift
// Henry/Config.swift
struct Config {
    static let anthropicAPIKey: String = "sk-ant-api03-YOUR-KEY-HERE"
}
```

> **Important**: `Config.swift` is git-ignored to protect your API key. Never commit it to version control.

### 3. Open in Xcode

```bash
open Henry.xcodeproj
```

### 4. Build and Run

1. Select your iPad or iPad Simulator as the target device
2. Press `Cmd + R` to build and run

## Project Structure

```
Henry/
├── HenryApp.swift              # App entry point with SwiftData setup
├── Models/
│   ├── Conversation.swift      # Chat conversation model
│   ├── Message.swift           # Individual message model
│   └── Artifact.swift          # Code/HTML artifact model
├── Services/
│   ├── AnthropicService.swift  # Claude API client with streaming
│   └── WebSearchService.swift  # Web search and content fetching
├── Views/
│   ├── MainView.swift          # Split view container
│   ├── ChatView.swift          # Main chat interface
│   ├── ChatViewModel.swift     # Chat state management
│   ├── MessageBubble.swift     # Message UI component
│   ├── ArtifactView.swift      # Artifact preview panel
│   ├── WebBrowserView.swift    # In-app web browser
│   └── SettingsView.swift      # App settings
├── Theme/
│   └── AppTheme.swift          # Colors, typography, styles
├── Extensions/                  # Swift extensions
├── Assets.xcassets/            # App icons and images
└── Config.swift                # API keys (git-ignored)
```

## API Models Supported

| Model | ID | Best For |
|-------|-----|----------|
| Claude Sonnet 4 | `claude-sonnet-4-20250514` | Balanced performance (default) |
| Claude 3.5 Sonnet | `claude-3-5-sonnet-20241022` | Previous generation balanced |
| Claude 3.5 Haiku | `claude-3-5-haiku-20241022` | Fast, simple tasks |
| Claude 3 Opus | `claude-3-opus-20240229` | Complex reasoning |

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistence for conversations and messages
- **MVVM Pattern**: Clean separation of concerns
- **Async/Await**: Modern concurrency for API calls
- **Server-Sent Events**: Real-time streaming responses

## Dependencies

| Package | Purpose |
|---------|---------|
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | Markdown rendering in chat |

## Privacy

- All conversations are stored locally on your device
- API calls are made directly to Anthropic's servers (https://api.anthropic.com)
- No data is collected or transmitted to third parties
- Web browsing is sandboxed within the app

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Anthropic](https://anthropic.com) for the Claude API
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) for excellent markdown rendering

---

Built with Claude

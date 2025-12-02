# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Henry is an iPad chat application powered by Anthropic's Claude API. It features real-time streaming responses, Apple Pencil annotation with multimodal image analysis, artifact extraction (code/HTML preview), and web browsing capabilities.

## Build Commands

```bash
# Open project in Xcode
open Henry.xcodeproj

# Build from command line
xcodebuild -project Henry.xcodeproj -scheme Henry -configuration Debug build

# Run tests
xcodebuild -project Henry.xcodeproj -scheme Henry -configuration Debug test -destination 'platform=macOS'

# Clean build
xcodebuild -project Henry.xcodeproj -scheme Henry clean
```

The app targets macOS 14.4+ (currently configured for macOS, despite README mentioning iPad).

## Configuration

Before running, copy `Henry/Config.example.swift` to `Henry/Config.swift` and add your Anthropic API key. `Config.swift` is git-ignored.

## Architecture

### Core Data Flow

1. **ChatViewModel** (`Views/ChatViewModel.swift`) - Main orchestrator handling user input, API calls, and state management. Uses `@MainActor` for thread safety.

2. **AnthropicService** (`Services/AnthropicService.swift`) - Actor-based API client supporting:
   - Text-only streaming via `streamMessage()`
   - Multimodal streaming via `streamMultimodalMessage()` for images
   - Server-Sent Events (SSE) parsing for real-time responses

3. **SwiftData Models** (`Models/`) - Persisted entities:
   - `Conversation` - Contains messages and optional system prompt
   - `Message` - Stores text, role, and image attachments (as JSON-encoded Data)
   - `Artifact` - Extracted code blocks from assistant responses

### Multimodal Flow

When a message contains images (annotations or attachments):
1. `Message.hasImages` returns true
2. `ChatViewModel.sendAnnotatedMessage()` is called
3. `AnthropicService.convertMessagesMultimodal()` formats messages with base64-encoded images
4. `streamMultimodalMessage()` sends to Claude's vision API

### Artifact Extraction

`Message.extractArtifacts()` uses regex to find code blocks in assistant responses and creates `Artifact` objects. Artifacts are categorized by type: code, html, markdown, mermaid, svg, react.

### Apple Pencil Annotation

`AnnotationView` uses PencilKit to overlay drawings on captured message content. The annotated image is captured via `UIGraphicsImageRenderer` and sent as a multimodal message.

## Key Dependencies

- **MarkdownUI** - Markdown rendering in chat
- **HTTPTypes** / **HTTPTypesFoundation** - HTTP type definitions
- **PencilKit** - Apple Pencil drawing (built-in)
- **SwiftData** - Local persistence (built-in)

## Theme System

`Theme/AppTheme.swift` defines Claude-inspired colors (`claudeOrange`, `claudeTan`), spacing constants via `Spacing` enum, and reusable view modifiers like `chatBubble(isUser:)`.

## Testing

Tests are in `HenryTests/` with mock services in `TestHelpers/MockConfig.swift`. Use `MockAnthropicService` and `MockWebSearchService` for unit tests without real API calls.

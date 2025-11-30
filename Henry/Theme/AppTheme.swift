import SwiftUI

// MARK: - App Colors

extension Color {
    // Primary brand colors (Claude-inspired)
    static let claudeOrange = Color(red: 217/255, green: 119/255, blue: 87/255)
    static let claudeTan = Color(red: 204/255, green: 169/255, blue: 154/255)

    // Background colors
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground)

    // Chat bubble colors
    static let userBubble = Color.claudeOrange
    static let assistantBubble = Color(uiColor: .secondarySystemBackground)

    // Sidebar
    static let sidebarBackground = Color(uiColor: .systemGroupedBackground)
    static let sidebarSelected = Color.claudeOrange.opacity(0.15)

    // Text colors
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textOnOrange = Color.white

    // Accent
    static let accent = Color.claudeOrange

    // Code blocks
    static let codeBackground = Color(red: 40/255, green: 42/255, blue: 54/255)
    static let codeText = Color(red: 248/255, green: 248/255, blue: 242/255)

    // Artifact panel
    static let artifactBackground = Color(uiColor: .tertiarySystemBackground)
    static let artifactBorder = Color(uiColor: .separator)
}

// MARK: - Typography

extension Font {
    static let chatInput = Font.body
    static let chatMessage = Font.body
    static let chatCode = Font.system(.body, design: .monospaced)
    static let sidebarTitle = Font.headline
    static let sidebarSubtitle = Font.subheadline
    static let artifactTitle = Font.headline
}

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    static let messagePadding: CGFloat = 12
    static let bubbleCornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 12
}

// MARK: - Shadows

extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    func subtleShadow() -> some View {
        self.shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.accent)
            .foregroundColor(.textOnOrange)
            .cornerRadius(Spacing.cardCornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.backgroundSecondary)
            .foregroundColor(.textPrimary)
            .cornerRadius(Spacing.cardCornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(Spacing.sm)
            .background(configuration.isPressed ? Color.backgroundSecondary : Color.clear)
            .cornerRadius(Spacing.sm)
    }
}

// MARK: - View Modifiers

struct ChatBubbleModifier: ViewModifier {
    let isUser: Bool

    func body(content: Content) -> some View {
        content
            .padding(Spacing.messagePadding)
            .background(isUser ? Color.userBubble : Color.assistantBubble)
            .foregroundColor(isUser ? .textOnOrange : .textPrimary)
            .cornerRadius(Spacing.bubbleCornerRadius)
    }
}

extension View {
    func chatBubble(isUser: Bool) -> some View {
        modifier(ChatBubbleModifier(isUser: isUser))
    }
}

// MARK: - Input Field Style

struct ChatInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.md)
            .background(Color.backgroundSecondary)
            .cornerRadius(Spacing.bubbleCornerRadius)
    }
}

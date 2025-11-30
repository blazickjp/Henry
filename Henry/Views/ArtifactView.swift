import SwiftUI
import WebKit

struct ArtifactView: View {
    let artifact: Artifact
    let onClose: () -> Void

    @State private var showShareSheet = false
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            artifactHeader

            Divider()

            // Content
            artifactContent
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Header

    private var artifactHeader: some View {
        HStack {
            // Title and type
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.title)
                    .font(.artifactTitle)
                    .foregroundColor(.textPrimary)

                Text(artifact.language.uppercased())
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(4)
            }

            Spacer()

            // Actions
            HStack(spacing: Spacing.sm) {
                // Copy Button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copiedToClipboard ? .green : .textSecondary)
                }
                .buttonStyle(IconButtonStyle())

                // Share Button
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(IconButtonStyle())

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(IconButtonStyle())
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
    }

    // MARK: - Content

    @ViewBuilder
    private var artifactContent: some View {
        switch artifact.type {
        case .html, .svg, .react:
            HTMLPreviewView(content: artifact.content, type: artifact.type)

        case .mermaid:
            MermaidPreviewView(content: artifact.content)

        case .code, .markdown:
            CodeView(code: artifact.content, language: artifact.language)
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        UIPasteboard.general.string = artifact.content
        copiedToClipboard = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

// MARK: - Code View

struct CodeView: View {
    let code: String
    let language: String

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color.codeText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.codeBackground)
    }
}

// MARK: - HTML Preview View

struct HTMLPreviewView: UIViewRepresentable {
    let content: String
    let type: ArtifactType

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = wrapInHTML(content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func wrapInHTML(_ content: String) -> String {
        switch type {
        case .html:
            // If it's already a complete HTML document, use it as-is
            if content.lowercased().contains("<html") {
                return content
            }
            // Otherwise wrap it
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        padding: 16px;
                        margin: 0;
                        background: #fff;
                        color: #333;
                    }
                    @media (prefers-color-scheme: dark) {
                        body { background: #1c1c1e; color: #fff; }
                    }
                </style>
            </head>
            <body>
                \(content)
            </body>
            </html>
            """

        case .svg:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body {
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        min-height: 100vh;
                        margin: 0;
                        padding: 16px;
                        box-sizing: border-box;
                        background: #fff;
                    }
                    svg { max-width: 100%; height: auto; }
                    @media (prefers-color-scheme: dark) {
                        body { background: #1c1c1e; }
                    }
                </style>
            </head>
            <body>
                \(content)
            </body>
            </html>
            """

        case .react:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
                <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
                <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        padding: 16px;
                        margin: 0;
                        background: #fff;
                        color: #333;
                    }
                    @media (prefers-color-scheme: dark) {
                        body { background: #1c1c1e; color: #fff; }
                    }
                </style>
            </head>
            <body>
                <div id="root"></div>
                <script type="text/babel">
                    \(content)
                    const root = ReactDOM.createRoot(document.getElementById('root'));
                    root.render(<App />);
                </script>
            </body>
            </html>
            """

        default:
            return content
        }
    }
}

// MARK: - Mermaid Preview View

struct MermaidPreviewView: UIViewRepresentable {
    let content: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <style>
                body {
                    display: flex;
                    justify-content: center;
                    padding: 16px;
                    margin: 0;
                    background: #fff;
                }
                @media (prefers-color-scheme: dark) {
                    body { background: #1c1c1e; }
                }
            </style>
        </head>
        <body>
            <div class="mermaid">
            \(content)
            </div>
            <script>
                mermaid.initialize({ startOnLoad: true, theme: 'default' });
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Preview

#Preview {
    ArtifactView(
        artifact: Artifact(
            type: .code,
            language: "swift",
            content: """
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }

            let message = greet(name: "World")
            print(message)
            """,
            title: "Greeting Function"
        ),
        onClose: {}
    )
}

import SwiftUI
import WebKit

struct WebBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webViewState = WebViewState()

    let initialURL: URL?
    let onSendToChat: ((String, String) -> Void)?

    @State private var urlText: String = ""
    @State private var showShareSheet = false

    init(url: URL? = nil, onSendToChat: ((String, String) -> Void)? = nil) {
        self.initialURL = url
        self.onSendToChat = onSendToChat
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URL Bar
                urlBar

                Divider()

                // WebView
                WebViewContainer(
                    state: webViewState,
                    initialURL: initialURL
                )

                // Bottom Toolbar
                bottomToolbar
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let onSendToChat = onSendToChat {
                        Button {
                            sendPageToChat(onSendToChat)
                        } label: {
                            Label("Send to Chat", systemImage: "bubble.left.and.text.bubble.right")
                        }
                    }
                }
            }
        }
        .onAppear {
            if let url = initialURL {
                urlText = url.absoluteString
            }
        }
        .onChange(of: webViewState.currentURL) { _, newURL in
            if let url = newURL {
                urlText = url.absoluteString
            }
        }
    }

    // MARK: - URL Bar

    private var urlBar: some View {
        HStack(spacing: Spacing.sm) {
            // Security indicator
            if webViewState.isSecure {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // URL TextField
            TextField("Enter URL or search", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit {
                    navigateToURL()
                }

            // Clear/Reload Button
            if !urlText.isEmpty {
                Button {
                    if webViewState.isLoading {
                        webViewState.stopLoading()
                    } else {
                        webViewState.reload()
                    }
                } label: {
                    Image(systemName: webViewState.isLoading ? "xmark" : "arrow.clockwise")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.backgroundSecondary)
        .cornerRadius(Spacing.sm)
        .padding()
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: Spacing.xl) {
            // Back
            Button {
                webViewState.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(!webViewState.canGoBack)

            // Forward
            Button {
                webViewState.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(!webViewState.canGoForward)

            Spacer()

            // Share
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
            }
            .disabled(webViewState.currentURL == nil)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .sheet(isPresented: $showShareSheet) {
            if let url = webViewState.currentURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Actions

    private func navigateToURL() {
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let url: URL?
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            url = URL(string: input)
        } else if input.contains(".") && !input.contains(" ") {
            url = URL(string: "https://\(input)")
        } else {
            // Search query
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            url = URL(string: "https://duckduckgo.com/?q=\(encoded)")
        }

        if let url = url {
            webViewState.load(url)
        }
    }

    private func sendPageToChat(_ handler: (String, String) -> Void) {
        let title = webViewState.pageTitle ?? "Web Page"
        let url = webViewState.currentURL?.absoluteString ?? ""
        let content = "Please summarize this web page:\n\nTitle: \(title)\nURL: \(url)"
        handler(title, content)
        dismiss()
    }
}

// MARK: - WebView State

class WebViewState: ObservableObject {
    @Published var currentURL: URL?
    @Published var pageTitle: String?
    @Published var isLoading: Bool = false
    @Published var isSecure: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    weak var webView: WKWebView?

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }
}

// MARK: - WebView Container

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var state: WebViewState
    let initialURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        state.webView = webView

        if let url = initialURL {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by coordinator
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = true
                self.state.currentURL = webView.url
                self.state.isSecure = webView.url?.scheme == "https"
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = false
                self.state.currentURL = webView.url
                self.state.pageTitle = webView.title
                self.state.canGoBack = webView.canGoBack
                self.state.canGoForward = webView.canGoForward
                self.state.isSecure = webView.url?.scheme == "https"
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.state.isLoading = false
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    WebBrowserView(url: URL(string: "https://anthropic.com"))
}

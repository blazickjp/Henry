import SwiftUI
import MarkdownUI

extension Color {
    static let amazonDarkBlue = Color(red: 18/255, green: 47/255, blue: 67/255)
    static let amazonOrange = Color(red: 255/255, green: 153/255, blue: 0/255)
    static let amazonLightOrange = Color(red: 255/255, green: 179/255, blue: 71/255)
}

struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct AppMenu: View {
    @StateObject private var viewModel = AppMenuViewModel()
    @State private var contentSize: CGSize = .zero
    @State private var responseBack: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.amazonDarkBlue, .amazonOrange]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer() // Pushes the content to the top

                VStack(alignment: .leading) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .amazonLightOrange))
                            .scaleEffect(2)
                            .padding()
                    } else {
                        ScrollView {
                            Markdown(viewModel.responseText)
                                .markdownTheme(.custom)
                                .padding()
                                .frame(maxWidth: 350, maxHeight: .infinity, alignment: .leading)
                                .background(Color.amazonDarkBlue.opacity(0.3))
                                .cornerRadius(10)
                                .padding()   
                        }
                    }

                    HStack {
                        TextField("Search...", text: $viewModel.userInput, onCommit: {
                            if !viewModel.userInput.isEmpty {
                                viewModel.fetchResponse()
                            }
                        })
                        .modifier(PlaceholderStyle(showPlaceholder: viewModel.userInput.isEmpty, placeholder: "Search..."))
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.amazonOrange.opacity(0.5))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.amazonDarkBlue, lineWidth: 1)
                        )
                    }
                    .padding()
                }
            }
            .frame(width: 350, height: 400) // Adjust height based on content
            .onPreferenceChange(ContentSizeKey.self) { size in
                self.contentSize = size
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AppMenu_Previews: PreviewProvider {
    static var previews: some View {
        AppMenu()
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct PlaceholderStyle: ViewModifier {
    var showPlaceholder: Bool
    var placeholder: String

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if showPlaceholder {
                Text(placeholder)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 30)
            }
            content
        }
    }
}

extension Theme {
    static let custom = Theme()
        .text {
            ForegroundColor(.white)
        }
        .code {
            FontFamilyVariant(.monospaced)
            ForegroundColor(.white)
            BackgroundColor(.black.opacity(0.2))
        }
        // Add more style configurations as needed
}

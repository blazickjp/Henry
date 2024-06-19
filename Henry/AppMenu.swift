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
                                .padding()
                                .frame(maxWidth: 350, maxHeight: .infinity, alignment: .leading)
                        }
                    }
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search...", text: $viewModel.userInput, onCommit: {
                            if !viewModel.userInput.isEmpty {
                                viewModel.fetchResponse()
                            }
                        })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding()
                .background(Color.amazonDarkBlue.opacity(0.3))
                .cornerRadius(20)
                .padding()
            }
            .frame(width: 350, height: 400) // Adjust height based on content
            .onPreferenceChange(ContentSizeKey.self) { size in
                self.contentSize = size
            }
        }
    }
}

struct AppMenu_Previews: PreviewProvider {
    static var previews: some View {
        AppMenu()
    }
}

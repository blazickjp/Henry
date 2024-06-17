import SwiftUI

struct AppMenu: View {
    @StateObject private var viewModel = AppMenuViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                        .padding()
                } else {
                    Text(viewModel.responseText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .animation(.easeInOut(duration: 0.5))
                }
                
                TextField("Enter your query here", text: $viewModel.userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    viewModel.fetchResponse()
                }) {
                    Text("Send Query")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
                
                Button(action: {
                    viewModel.fetchResponseWithClipboardContent()
                }) {
                    Text("Use Clipboard Content")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .frame(width: 300, height: 300)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding()
        }
    }
}

struct AppMenu_Previews: PreviewProvider {
    static var previews: some View {
        AppMenu()
    }
}

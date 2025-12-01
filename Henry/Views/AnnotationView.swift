import SwiftUI
import PencilKit

// MARK: - Annotation View

struct AnnotationView: View {
    @Binding var isPresented: Bool
    let contentToAnnotate: UIImage
    let onSend: (UIImage, String) -> Void

    @State private var canvasView = PKCanvasView()
    @State private var messageText: String = ""
    @State private var toolPickerVisible = true
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drawing canvas with content underneath
                ZStack {
                    // Background image to annotate
                    Image(uiImage: contentToAnnotate)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    // PencilKit canvas overlay
                    CanvasRepresentable(canvasView: $canvasView)
                        .background(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundSecondary)

                Divider()

                // Message input
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        TextField("Add a message about your drawing...", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...4)
                            .focused($isTextFieldFocused)

                        Button {
                            sendAnnotation()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.claudeOrange)
                        }
                    }
                    .padding()
                    .background(Color.backgroundSecondary)
                }
            }
            .navigationTitle("Annotate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        // Clear drawing
                        Button {
                            canvasView.drawing = PKDrawing()
                        } label: {
                            Image(systemName: "trash")
                        }

                        // Undo
                        Button {
                            canvasView.undoManager?.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }

                        // Redo
                        Button {
                            canvasView.undoManager?.redo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                        }
                    }
                }
            }
        }
    }

    private func sendAnnotation() {
        // Capture the annotated image
        let annotatedImage = captureAnnotatedImage()
        let message = messageText.isEmpty ? "What do you see in this annotated image?" : messageText

        onSend(annotatedImage, message)
        isPresented = false
    }

    private func captureAnnotatedImage() -> UIImage {
        // Create a renderer with the content size
        let renderer = UIGraphicsImageRenderer(size: contentToAnnotate.size)

        return renderer.image { context in
            // Draw the original content
            contentToAnnotate.draw(at: .zero)

            // Scale and draw the PencilKit drawing
            let drawingImage = canvasView.drawing.image(
                from: canvasView.bounds,
                scale: contentToAnnotate.size.width / canvasView.bounds.width
            )

            drawingImage.draw(in: CGRect(origin: .zero, size: contentToAnnotate.size))
        }
    }
}

// MARK: - Canvas Representable

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput // Allow finger and pencil
        canvasView.tool = PKInkingTool(.pen, color: .systemRed, width: 5)

        // Show tool picker
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Updates handled by binding
    }
}

// MARK: - Message Snapshot View

struct MessageSnapshotView: View {
    let message: Message
    @Binding var showAnnotation: Bool
    @State private var snapshotImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Snapshot target content
            MessageContentView(message: message)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                // Capture on appear for later use
                            }
                    }
                )

            // Annotate button
            if message.role == .assistant {
                Button {
                    captureAndShowAnnotation()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "pencil.tip.crop.circle")
                        Text("Annotate & Reply")
                            .font(.caption)
                    }
                    .foregroundColor(.claudeOrange)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.claudeOrange.opacity(0.1))
                    .cornerRadius(Spacing.sm)
                }
            }
        }
    }

    private func captureAndShowAnnotation() {
        // Will be implemented in the parent view
        showAnnotation = true
    }
}

// MARK: - Message Content View (for snapshot)

struct MessageContentView: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(message.content)
                .font(.body)
                .foregroundColor(.textPrimary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(Spacing.cardCornerRadius)
    }
}

// MARK: - View Snapshot Extension

extension View {
    /// Capture a snapshot of the view as UIImage
    @MainActor
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view!

        let targetSize = controller.view.intrinsicContentSize
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Capture a snapshot with a specific size
    @MainActor
    func snapshot(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view!

        view.bounds = CGRect(origin: .zero, size: size)
        view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - Preview

#Preview {
    AnnotationView(
        isPresented: .constant(true),
        contentToAnnotate: UIImage(systemName: "photo")!,
        onSend: { _, _ in }
    )
}

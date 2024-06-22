import Cocoa

class ScreenCaptureService {
    static func captureScreen() -> NSImage? {
        if let screen = NSScreen.main {
            let rect = screen.frame
            if let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
                return NSImage(cgImage: cgImage, size: rect.size)
            }
        }
        return nil
    }
}

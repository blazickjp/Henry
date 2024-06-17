import SwiftUI

@main
struct HenryApp: App {
    var body: some Scene {
        MenuBarExtra("Henry", systemImage: "hammer") {
            AppMenu()
        }.menuBarExtraStyle(.window)

        WindowGroup {
        }
    }
}

import SwiftData
import SwiftUI

@main
struct ParlaApp: App {
    @State private var preferences = Preferences()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .tint(Theme.accent(.light))
        }
        .modelContainer(Store.container())
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 820)
        #endif
    }
}

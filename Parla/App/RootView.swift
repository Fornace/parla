import SwiftUI

enum Route: Hashable {
    case settings
    case history
    case phrasebook
    case practice(UUID)
}

struct RootView: View {
    @State private var path = NavigationPath()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .history:
                        HistoryView()
                    case .phrasebook:
                        PhrasebookView()
                    case .practice(let id):
                        SavedDebriefView(practiceID: id)
                    }
                }
        }
        .background(Theme.paper(scheme))
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }
}

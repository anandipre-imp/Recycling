import SwiftUI

@main
struct GalleryMatcherApp: App {
    @State private var model = LibraryModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    // Pick up videos recorded while the app was in the background.
                    if phase == .active { Task { await model.refresh() } }
                }
        }
    }
}

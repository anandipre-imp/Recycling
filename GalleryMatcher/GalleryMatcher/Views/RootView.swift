import SwiftUI

struct RootView: View {
    @Environment(LibraryModel.self) private var model

    var body: some View {
        switch model.access {
        case .notDetermined:
            OnboardingView()
        case .denied:
            AccessDeniedView()
        case .limited, .full:
            TabView {
                CreateView()
                    .tabItem { Label("Create", systemImage: "wand.and.stars") }
                LibraryView()
                    .tabItem { Label("Library", systemImage: "square.grid.2x2") }
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(LibraryModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Turn your camera roll into content")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                Label("Finds videos that go together — same trip, same scene, same vibe.", systemImage: "rectangle.3.group")
                Label("Type what you want to make and get ready-to-export ideas.", systemImage: "text.cursor")
                Label("All analysis happens on your iPhone. Your videos never leave it.", systemImage: "lock.shield")
            }
            .font(.body)
            Spacer()
            Button {
                Task { await model.requestAccess() }
            } label: {
                Text("Allow access to videos").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }
}

struct AccessDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No access to your videos", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Allow photo library access in Settings so the app can find videos to work with.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

import SwiftUI

struct CreateView: View {
    @Environment(LibraryModel.self) private var model
    @State private var query = ""
    @FocusState private var isEditing: Bool

    private let examples = ["Beach trip reel", "My dog compilation", "What I ate this month", "Gym montage", "Sunset aesthetic", "YouTube travel vlog"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("What do you want to make?", text: $query)
                        .focused($isEditing)
                        .submitLabel(.search)
                        .onSubmit(runSearch)
                    Button(action: runSearch) {
                        Label("Find matching videos", systemImage: "sparkle.magnifyingglass")
                    }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || model.isSearching)
                } footer: {
                    IndexingStatus()
                }

                if model.lastQuery == nil {
                    Section("Try") {
                        ForEach(examples, id: \.self) { example in
                            Button(example) {
                                query = example
                                runSearch()
                            }
                        }
                    }
                } else if model.isSearching {
                    Section { ProgressView("Looking through your videos…") }
                } else if model.ideas.isEmpty {
                    ContentUnavailableView(
                        "No matching videos yet",
                        systemImage: "film",
                        description: Text(model.isIndexing
                            ? "Still analyzing your library — try again in a bit, or try different words."
                            : "Try different words, like a place, an activity or an animal.")
                    )
                } else {
                    Section {
                        ForEach(model.ideas) { idea in
                            IdeaCard(idea: idea)
                        }
                    } header: {
                        Text("\(model.matchCount) matching videos · \(model.ideas.count) ideas")
                    } footer: {
                        Label(model.ideasUsedAppleIntelligence ? "Titles written with Apple Intelligence" : "Titles written on this iPhone",
                              systemImage: model.ideasUsedAppleIntelligence ? "sparkles" : "text.badge.star")
                    }
                }
            }
            .navigationTitle("Create")
        }
    }

    private func runSearch() {
        isEditing = false
        let text = query
        Task { await model.search(text) }
    }
}

struct IndexingStatus: View {
    @Environment(LibraryModel.self) private var model

    var body: some View {
        if model.isIndexing {
            HStack(spacing: 8) {
                ProgressView()
                Text("Analyzing \(model.analyzedCount) of \(model.totalVideos) videos… results improve as this runs.")
            }
        } else {
            Text("\(model.analyzedCount) videos analyzed on this iPhone.")
        }
    }
}

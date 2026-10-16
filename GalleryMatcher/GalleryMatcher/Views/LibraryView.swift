import SwiftUI

struct LibraryView: View {
    @Environment(LibraryModel.self) private var model
    @State private var groups: [VideoCluster] = []
    @State private var tags: [TagCount] = []
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.totalVideos > 0 {
                        ProgressView(value: Double(model.analyzedCount), total: Double(model.totalVideos)) {
                            Text("\(model.analyzedCount) of \(model.totalVideos) videos analyzed")
                        }
                    }
                    if model.access == .limited {
                        Label("You've shared only some videos with the app. Allow full access in Settings to analyze everything.",
                              systemImage: "exclamationmark.circle")
                            .font(.footnote)
                    }
                }

                if !tags.isEmpty {
                    Section("What's in your videos") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(tags, id: \.name) { tag in
                                Text("\(tag.name) · \(tag.videos)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Videos that go together") {
                    if groups.isEmpty {
                        Text(model.isIndexing ? "Groups appear as videos are analyzed." : "No groups found yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(groups) { group in
                        NavigationLink {
                            ClusterDetailView(cluster: group)
                        } label: {
                            ClusterRow(cluster: group)
                        }
                    }
                }

                Section {
                    Button("Re-analyze all videos", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Library")
            .task(id: model.analyzedCount / 25) { reload() }
            .confirmationDialog("Discard all analysis and start over?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Re-analyze", role: .destructive) { Task { await model.resetAnalysis() } }
            }
        }
    }

    private func reload() {
        groups = model.discoveredGroups()
        tags = model.topTags()
    }
}

struct ClusterRow: View {
    let cluster: VideoCluster

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(videoID: cluster.members[0].id, size: CGSize(width: 56, height: 56))
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.topLabels(3).joined(separator: ", ").capitalized).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        var text = "\(cluster.members.count) videos"
        if let date = cluster.startDate {
            text += " · " + date.formatted(date: .abbreviated, time: .omitted)
        }
        return text
    }
}

struct ClusterDetailView: View {
    let cluster: VideoCluster

    var body: some View {
        List(cluster.members) { video in
            HStack(spacing: 12) {
                ThumbnailView(videoID: video.id, size: CGSize(width: 64, height: 96))
                VStack(alignment: .leading, spacing: 6) {
                    if let date = video.creationDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold())
                    }
                    Text("\(Int(video.duration.rounded()))s\(video.maxFaceCount > 0 ? " · \(video.maxFaceCount) face(s)" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(video.labels.prefix(6).map { "\($0.name) \(Int($0.confidence * 100))%" }.joined(separator: ", "))
                        .font(.caption)
                }
            }
        }
        .navigationTitle("\(cluster.members.count) videos")
    }
}

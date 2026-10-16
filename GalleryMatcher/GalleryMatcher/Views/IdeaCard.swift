import SwiftUI

struct IdeaCard: View {
    @Environment(LibraryModel.self) private var model
    let idea: ContentIdea

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title).font(.headline)
                Text("“\(idea.hook)”").font(.subheadline).foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(idea.clips, id: \.self) { clip in
                        ThumbnailView(videoID: clip.videoID, size: CGSize(width: 72, height: 110))
                    }
                }
            }

            TagRow(tags: idea.cluster.topLabels(4))

            HStack {
                Text("\(idea.clips.count) clips · ~\(Int(idea.totalDuration.rounded()))s · \(idea.format.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                exportButton
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var exportButton: some View {
        switch model.exportState {
        case .exporting(let id) where id == idea.id:
            ProgressView()
        case .saved(let id) where id == idea.id:
            Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
        case .failed(let id, let message) where id == idea.id:
            Button("Retry") { Task { await model.makeVideo(idea) } }
                .help(message)
        default:
            Button("Make video") { Task { await model.makeVideo(idea) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isExportingAnother)
        }
    }

    private var isExportingAnother: Bool {
        if case .exporting = model.exportState { return true }
        return false
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }
}

struct ThumbnailView: View {
    @Environment(LibraryModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    let videoID: String
    let size: CGSize
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: videoID) {
            image = await model.thumbnail(
                for: videoID,
                size: CGSize(width: size.width * displayScale, height: size.height * displayScale)
            )
        }
    }
}

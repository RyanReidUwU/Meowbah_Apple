import WidgetKit
import SwiftUI

fileprivate func subtitle(for snippet: VideoSnippet) -> String {
    // Return an empty subtitle for now; properties like `channel` or `published` may not exist on VideoSnippet in this project.
    // If needed, update this to use actual available properties from VideoSnippet.
    return ""
}

fileprivate func subtitleText(for snippet: VideoSnippet) -> Text? {
    let sub = subtitle(for: snippet)
    return sub.isEmpty ? nil : Text(sub)
}

private struct ThumbnailView: View {
    let data: Data?
    let cornerRadius: CGFloat

    private func image(from data: Data?) -> (Image, Bool) {
        guard let data else { return (Image(systemName: "play.rectangle.fill"), false) }
        #if canImport(UIKit)
        if let ui = UIImage(data: data) { return (Image(uiImage: ui), true) }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) { return (Image(nsImage: ns), true) }
        #endif
        return (Image(systemName: "play.rectangle.fill"), false)
    }

    var body: some View {
        let (thumb, hasImage) = image(from: data)
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
            thumb
                .resizable()
                .scaledToFill()
                .opacity(hasImage ? 1 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct MostRecentVideoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MostRecentVideoEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                // fallback to mediumView if small or other
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var mediumView: some View {
        Group {
            if let snippet = entry.videos.first {
                HStack(alignment: .top, spacing: 10) {
                    ThumbnailView(data: snippet.thumbnailData, cornerRadius: 10)
                        .frame(width: 96, height: 56)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Most Recent Video")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(snippet.title)
                            .font(.system(.headline, design: .rounded))
                            .lineLimit(3)

                        if let subText = subtitleText(for: snippet) {
                            subText
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding()
                .widgetURL(snippet.url)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 96, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Most Recent Video")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("No videos available")
                            .font(.system(.headline, design: .rounded))
                            .lineLimit(3)

                        Spacer(minLength: 0)
                    }
                }
                .padding()
                .widgetURL(nil)
            }
        }
    }

    private var largeView: some View {
        let items = Array(entry.videos.prefix(4))
        let placeholders = max(0, 4 - items.count)

        return VStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, snippet in
                HStack(spacing: 0) {
                    VideoRowView(snippet: snippet)
                        .padding(.horizontal)
                }
                .widgetURL(snippet.url)
            }

            if placeholders > 0 {
                ForEach(0..<placeholders, id: \.self) { _ in
                    HStack(spacing: 0) {
                        PlaceholderRowView()
                            .padding(.horizontal)
                    }
                    .widgetURL(nil)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

private struct VideoRowView: View {
    let snippet: VideoSnippet

    var body: some View {
        HStack(spacing: 10) {
            ThumbnailView(data: snippet.thumbnailData, cornerRadius: 10)
                .frame(width: 96, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(snippet.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(3)

                if let subText = subtitleText(for: snippet) {
                    subText
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PlaceholderRowView: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 96, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("No video")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Check back later")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}
#if DEBUG
import WidgetKit

private struct _SampleVideoSnippet: Identifiable {
    let id = UUID()
    let title: String
    let thumbnailData: Data?
    let url: URL?
}

private extension _SampleVideoSnippet {
    var asVideoSnippet: VideoSnippet {
        // Bridge helper to construct a VideoSnippet using the minimal properties used by the widget.
        // Assumes VideoSnippet has an initializer or can be created with these properties. If not, adjust to your model.
        // Replace this with your app's actual way of creating a VideoSnippet from raw values if needed.
        return VideoSnippet(title: title, url: url, thumbnailData: thumbnailData)
    }
}

#Preview("Large - 4 Items") {
    // Build 4 sample items
    let samples: [VideoSnippet] = (1...4).map { i in
        let title = "Sample Video #\(i)"
        let data: Data? = nil
        let url = URL(string: "https://example.com/video/\(i)")
        return _SampleVideoSnippet(title: title, thumbnailData: data, url: url).asVideoSnippet
    }

    let entry = MostRecentVideoEntry(date: Date(), videos: samples)
    MostRecentVideoWidgetView(entry: entry)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
}
#endif

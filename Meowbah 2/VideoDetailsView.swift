import SwiftUI

struct VideoDetailsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    let video: Video

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = video.thumbnailURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.frame(height: 180)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(video.title)
                    .font(.title2).bold()
                    .foregroundStyle(palette.textPrimary)

                if !video.publishedAtFormatted.isEmpty {
                    Text(video.publishedAtFormatted)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }

                HStack {
                    if !video.formattedDuration.isEmpty {
                        Label(video.formattedDuration, systemImage: "clock")
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    if let url = video.watchURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Watch on YouTube", systemImage: "play.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.primary)
                    }
                }
            }
            .padding(16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Video Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#Preview {
    let sample = Video(
        id: "abc123",
        title: "Sample Video Title",
        description: "Description",
        thumbnailURL: URL(string: "https://i.ytimg.com/vi/abc123/hqdefault.jpg"),
        publishedAt: Date(),
        channelTitle: "Channel",
        durationSeconds: 245
    )
    return NavigationStack {
        VideoDetailsView(video: sample)
            .environmentObject(ThemeManager())
    }
}

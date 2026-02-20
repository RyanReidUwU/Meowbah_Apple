//
//  VideosView.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Local Notifications

private enum NotificationManager {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do { _ = try await center.requestAuthorization(options: [.alert, .badge, .sound]) } catch { }
    }

    static func scheduleNewVideoNotification(video: Video) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Nyaa~ New video just dropped!"
        content.body = video.title.isEmpty ? "Tap to watch meow!" : "“\(video.title)” is ready to watch. Tap to play!"
        content.sound = .default
        content.badge = NSNumber(value: 1)

        let request = UNNotificationRequest(
            identifier: "new-video-\(video.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )

        do { try await UNUserNotificationCenter.current().add(request) } catch { }

        if let url = video.thumbnailURL {
            Task.detached(priority: .utility) {
                do {
                    let req = ImageLoaderConfig.request(for: url)
                    let (data, _) = try await ImageLoaderConfig.session.data(for: req)
                    let tmpURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("thumb-\(video.id).jpg")
                    try? FileManager.default.removeItem(at: tmpURL)
                    try data.write(to: tmpURL)
                    let attachment = try UNNotificationAttachment(identifier: "thumb", url: tmpURL, options: nil)
                    let updated = UNMutableNotificationContent()
                    updated.title = content.title
                    updated.body = content.body
                    updated.sound = content.sound
                    updated.badge = content.badge
                    updated.attachments = [attachment]
                    let updatedRequest = UNNotificationRequest(
                        identifier: "new-video-\(video.id)",
                        content: updated,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    )
                    try? await UNUserNotificationCenter.current().add(updatedRequest)
                } catch { }
            }
        }
    }
}

// MARK: - Fast in-memory image cache

private final class ThumbnailCache {
    #if canImport(UIKit)
    typealias PlatformImage = UIImage
    #elseif canImport(AppKit)
    typealias PlatformImage = NSImage
    #else
    // Default to a generic AnyObject to avoid compile errors on unknown platforms
    typealias PlatformImage = AnyObject
    #endif

    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, PlatformImage>()
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: PlatformImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - ThumbnailView (no downscaling)

private struct ThumbnailView: View {
    let url: URL
    let size: CGSize
    let cornerRadius: CGFloat

    @State private var uiImage: ThumbnailCache.PlatformImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let uiImage {
                if let image = platformImage(from: uiImage) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    // Fallback if no platform image initializer is available
                    Color.clear
                }
            } else {
                ProgressView().tint(.white)
                    .task(id: url) {
                        await load()
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func load() async {
        if let cached = ThumbnailCache.shared.image(for: url) {
            self.uiImage = cached
            return
        }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let req = ImageLoaderConfig.request(for: url)
            let (data, response) = try await ImageLoaderConfig.session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
#if canImport(UIKit)
            guard let image = UIImage(data: data) else { return }
#else
            guard let image = NSImage(data: data) else { return }
#endif

            ThumbnailCache.shared.set(image, for: url, cost: data.count)
            await MainActor.run { self.uiImage = image }
        } catch { }
    }
    
    private func platformImage(from platformImage: ThumbnailCache.PlatformImage) -> Image? {
    #if canImport(UIKit)
        if let image = platformImage as? UIImage {
            return Image(uiImage: image)
        }
        return nil
    #elseif canImport(AppKit)
        if let image = platformImage as? NSImage {
            return Image(nsImage: image)
        }
        return nil
    #else
        return nil
    #endif
    }
}

// MARK: - iOS-only Animated GIF helper

#if canImport(UIKit)
private struct AnimatedGIFView: UIViewRepresentable {
    let data: Data
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = contentMode // show full image
        iv.clipsToBounds = false     // do not crop
        // Prevent stretching/expansion
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .vertical)
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentHuggingPriority(.required, for: .vertical)
        iv.image = animatedImage(fromGIFData: data)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) { }

    private func animatedImage(fromGIFData data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        var images: [UIImage] = []
        images.reserveCapacity(count)
        var duration: Double = 0

        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            let frameDuration = frameDurationAt(index: i, source: src)
            duration += frameDuration
            images.append(UIImage(cgImage: cg))
        }
        if duration <= 0 { duration = Double(count) * (1.0 / 10.0) }
        return UIImage.animatedImage(with: images, duration: duration)
    }

    private func frameDurationAt(index: Int, source: CGImageSource) -> Double {
        let defaultFrameDuration = 0.1
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return defaultFrameDuration
        }
        let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifDict[kCGImagePropertyGIFDelayTime] as? Double
        let val = unclamped ?? clamped ?? defaultFrameDuration
        return val < 0.011 ? 0.1 : val // avoid too-fast frames
    }
}
#endif

// MARK: - View

struct VideosView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var isRefreshing = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var quotaBannerMessage: String?
    @State private var videos: [Video] = []

    // Track previously seen IDs to detect new items
    @State private var knownVideoIDs: Set<String> = []

    // Sorting / Filtering
    private enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case date = "Date"
        case duration = "Duration"
        var id: String { rawValue }
    }
    @State private var selectedSort: SortOption = .date
    @State private var durationAscending: Bool = true

    // Removed the channelId property here

    private var filteredVideos: [Video] {
        let base: [Video] = searchText.isEmpty
            ? videos
            : videos.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.description.localizedCaseInsensitiveContains(searchText)
            }

        switch selectedSort {
        case .name:
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .date:
            return base.sorted {
                ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
            }
        case .duration:
            return base.sorted {
                let l = $0.durationSeconds ?? Int.max
                let r = $1.durationSeconds ?? Int.max
                return durationAscending ? (l < r) : (l > r)
            }
        }
    }

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        NavigationStack {
            ZStack {
                // Always paint the themed background and ignore safe areas to prevent black borders
                palette.background
                    .ignoresSafeArea()

                if colorScheme == .dark {
                    LinearGradient(
                        colors: [Color.black.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let layout = LayoutChoice.forWidth(width)

                    VStack(spacing: 0) {
                        if let banner = quotaBannerMessage, !banner.isEmpty {
                            Text(banner)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(
                                    LinearGradient(
                                        colors: [palette.primary.opacity(0.9), palette.secondary.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Group {
                            if isLoading && videos.isEmpty {
                                ProgressView("Loading videos…")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if let errorMessage, videos.isEmpty {
                                errorState(palette: palette, message: errorMessage)
                            } else {
                                content(layout: layout, palette: palette)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
#if canImport(UIKit)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search cute videos")
#else
            .searchable(text: $searchText, prompt: "Search cute videos")
#endif
            .toolbar {
#if canImport(UIKit)
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort by", selection: $selectedSort) {
                            Label("Sort by Name", systemImage: "textformat").tag(SortOption.name)
                            Label("Sort by Date", systemImage: "calendar").tag(SortOption.date)
                            Label("Sort by Duration", systemImage: "clock").tag(SortOption.duration)
                        }
                        .pickerStyle(.inline)

                        if selectedSort == .duration {
                            Toggle(isOn: $durationAscending) {
                                Label("Shortest first", systemImage: durationAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter videos")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadVideos(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(palette.primary)
                    }
                    .disabled(isLoading)
                }
#endif
            }
            .refreshable {
                isRefreshing = true
                await loadVideos(force: true)
                await MainActor.run { isRefreshing = false }
            }
            .task {
                if videos.isEmpty {
                    await loadVideos(force: false)
                }
            }
        }
#if canImport(UIKit)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        .tint(palette.primary)
    }

    // MARK: - Layout switching

    private enum LayoutChoice {
        case list
        case grid(columns: Int)

        static func forWidth(_ width: CGFloat) -> LayoutChoice {
            switch width {
            case ..<600: return .list
            case 600..<900: return .grid(columns: 2)
            default: return .grid(columns: 3)
            }
        }
    }

    @ViewBuilder
    private func content(layout: LayoutChoice, palette: ThemePalette) -> some View {
        switch layout {
        case .list:
            List {
                ForEach(filteredVideos) { video in
                    NavigationLink(value: video) {
                        VideoRow(video: video)
                    }
                    .listRowBackground(Color.clear)
                    .background(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .navigationDestination(for: Video.self) { video in
                VideoDetailView(video: video)
            }

        case .grid(let cols):
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: cols), spacing: 16) {
                    ForEach(filteredVideos) { video in
                        NavigationLink(value: video) {
                            VideosGridItem(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.clear)
            }
            .navigationDestination(for: Video.self) { video in
                VideoDetailView(video: video)
            }
        }
    }

    @ViewBuilder
    private func errorState(palette: ThemePalette, message: String) -> some View {
        VStack(spacing: 12) {
#if canImport(UIKit)
            if let data = NSDataAsset(name: "ErrorGIF")?.data {
                HStack {
                    AnimatedGIFView(data: data, contentMode: .scaleAspectFit)
                        .frame(width: 48, height: 48, alignment: .center) // strict cap
                        .fixedSize()                                        // prevent expansion
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, -6)
            } else {
                // Fallback if asset is missing
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(palette.primary)
                    .padding(.top, -6)
            }
#else
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(palette.primary)
                .padding(.top, -6)
#endif

            Text("Failed to load videos")
                .font(.title2).bold()
                .foregroundStyle(palette.textPrimary)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 20)

            Button {
                Task { await loadVideos(force: true) }
            } label: {
                Text("Retry").bold()
            }
            .tint(palette.primary)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    // MARK: - Actions

    private func loadVideos(force: Bool = false) async {
        if await isCurrentlyLoadingAndNotForced(force: force) { return }
        await MainActor.run {
            self.errorMessage = nil
            self.quotaBannerMessage = nil
            self.isLoading = true
        }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let fetched = try await YouTubeAPIClient.shared.fetchLatestVideos(maxResults: 25)
            await MainActor.run {
                self.videos = fetched
                self.knownVideoIDs = Set(fetched.map { $0.id })
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    @MainActor
    private func isCurrentlyLoadingAndNotForced(force: Bool) -> Bool {
        return isLoading && !force
    }
}

struct VideoRow: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    let video: Video

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        HStack(spacing: 12) {
            thumbnail(palette: palette, size: CGSize(width: 96, height: 56), corner: 12)
            texts(palette: palette)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.clear)
    }

    private func thumbnail(palette: ThemePalette, size: CGSize, corner: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width, height: size.height)

            if let url = video.thumbnailURL {
                ThumbnailView(url: url, size: size, cornerRadius: corner)
            } else {
                Image(systemName: "play.rectangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .foregroundStyle(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: corner))
            }

            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .accessibilityHidden(true)
        .background(Color.clear)
    }

    private func texts(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                if !video.formattedDuration.isEmpty {
                    Text(video.formattedDuration)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(palette.card.opacity(0.8))
                        )
                        .foregroundStyle(palette.textPrimary)
                }
            }
            if !video.publishedAtFormatted.isEmpty {
                Text(video.publishedAtFormatted)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            if !video.description.isEmpty {
                Text(video.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .background(Color.clear)
    }
}

// Grid item variant for wider layouts
private struct VideosGridItem: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    let video: Video

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 128, height: 72)

                if let url = video.thumbnailURL {
                    ThumbnailView(url: url, size: CGSize(width: 128, height: 72), cornerRadius: 12)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 72)
                        .foregroundStyle(.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Image(systemName: "play.fill")
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if !video.formattedDuration.isEmpty {
                        Text(video.formattedDuration)
                            .font(.caption2).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(palette.card.opacity(0.8))
                            )
                            .foregroundStyle(palette.textPrimary)
                    }
                    if !video.publishedAtFormatted.isEmpty {
                        Text(video.publishedAtFormatted)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail View

private struct VideoDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let video: Video
    @State private var showSafari = false

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [palette.primary, palette.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)

                    if let url = video.thumbnailURL {
                        GeometryReader { geo in
                            let availableWidth = geo.size.width
                            ThumbnailView(url: url, size: CGSize(width: availableWidth, height: 200), cornerRadius: 16)
                                .frame(width: availableWidth, height: 200, alignment: .center)
                        }
                        .frame(height: 200)
                    }

                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }

                // Title
                Text(video.title)
                    .font(.title2).bold()
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)

                // Date
                if !video.publishedAtFormatted.isEmpty {
                    Text("Posted \(video.publishedAtFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }

                // Description
                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.body)
                        .foregroundColor(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                }

                // Play Button -> Full-screen Safari
                if let url = video.watchURL {
                    Button {
                        showSafari = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Play on YouTube").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [palette.primary, palette.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
#if canImport(SafariServices) && canImport(UIKit)
                    .fullScreenCover(isPresented: $showSafari) {
                        YouTubeSafariView(url: url)
                            .ignoresSafeArea()
                            // Pause audio when Safari opens, resume when it closes.
                            .onAppear {
                                AudioPlayback.shared.pause()
                            }
                            .onDisappear {
                                AudioPlayback.shared.resume()
                            }
                    }
#else
#if canImport(UIKit)
                    .onTapGesture {
                        UIApplication.shared.open(url)
                    }
#else
                    .onTapGesture {
                        NSWorkspace.shared.open(url)
                    }
#endif
#endif
                }
            }
            .padding(16)
        }
        .background(
            ZStack { theme.palette(for: colorScheme).background.ignoresSafeArea() }
        )
        .navigationTitle("Video")
    }
}

// MARK: - Safari wrapper

#if canImport(SafariServices) && canImport(UIKit)
import SwiftUI
import SafariServices
import UIKit
private struct YouTubeSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = UIColor.clear
        vc.preferredControlTintColor = UIColor.label
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
#endif

#Preview {
    VideosView()
        .environmentObject(ThemeManager())
}


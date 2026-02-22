//
//  VideosView.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
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

// MARK: - Widget: Most Recent Video (App Group)
#if !os(tvOS)
private enum MostRecentVideoWidgetWriter {
    static let groupID = "group.meowbah"
    static let mostRecentTitle = "videos.mostRecent.title"
    static let mostRecentChannel = "videos.mostRecent.channel"
    static let mostRecentDate = "videos.mostRecent.date" // seconds since 1970
    static let mostRecentURL = "videos.mostRecent.url"
    static let mostRecentThumbnailURL = "videos.mostRecent.thumbnailURL"
    static let mostRecentThumbnailFile = "videos.mostRecent.thumbnailFile"
    static let mostRecentDescription = "videos.mostRecent.description"

    static let secondTitle = "videos.second.title"
    static let secondDate = "videos.second.date"
    static let secondURL = "videos.second.url"
    static let secondThumbnailFile = "videos.second.thumbnailFile"
    static let secondDescription = "videos.second.description"

    static let thirdTitle = "videos.third.title"
    static let thirdDate = "videos.third.date"
    static let thirdURL = "videos.third.url"
    static let thirdThumbnailFile = "videos.third.thumbnailFile"
    static let thirdDescription = "videos.third.description"

    static let fourthTitle = "videos.fourth.title"
    static let fourthDate = "videos.fourth.date"
    static let fourthURL = "videos.fourth.url"
    static let fourthThumbnailFile = "videos.fourth.thumbnailFile"
    static let fourthDescription = "videos.fourth.description"

    static func save(from videos: [Video]) {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }

        // Pick newest by publishedAt (fallback to first if missing).
        let sorted = videos
            .sorted(by: { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) })
        let mostRecent = sorted.first ?? videos.first
        let second = sorted.dropFirst().first
        let third = sorted.dropFirst(2).first
        let fourth = sorted.dropFirst(3).first

        guard let video = mostRecent else { return }

        defaults.set(video.title, forKey: mostRecentTitle)

        // Channel isn't available in your Video model here — clear it for now.
        defaults.removeObject(forKey: mostRecentChannel)

        if let published = video.publishedAt {
            defaults.set(published.timeIntervalSince1970, forKey: mostRecentDate)
        } else {
            defaults.removeObject(forKey: mostRecentDate)
        }

        if let url = video.watchURL {
            defaults.set(url.absoluteString, forKey: mostRecentURL)
        } else {
            defaults.removeObject(forKey: mostRecentURL)
        }
        defaults.set(video.description, forKey: mostRecentDescription)

        // Save a thumbnail URL for the widget.
        var thumb: URL? = video.thumbnailURL

        // If the model didn't provide one, derive it from the watch URL.
        if thumb == nil {
            thumb = fallbackYouTubeThumbnail(from: video.watchURL)
        }

        if var thumb {
            // Widgets can be picky about non-HTTPS loads; ensure https if possible.
            if thumb.scheme?.lowercased() == "http" {
                var comps = URLComponents(url: thumb, resolvingAgainstBaseURL: false)
                comps?.scheme = "https"
                if let httpsURL = comps?.url { thumb = httpsURL }
            }
            defaults.set(thumb.absoluteString, forKey: mostRecentThumbnailURL)
        } else {
            defaults.removeObject(forKey: mostRecentThumbnailURL)
        }
        
        if let second {
            defaults.set(second.title, forKey: secondTitle)
            if let published = second.publishedAt {
                defaults.set(published.timeIntervalSince1970, forKey: secondDate)
            } else {
                defaults.removeObject(forKey: secondDate)
            }
            if let url = second.watchURL {
                defaults.set(url.absoluteString, forKey: secondURL)
            } else {
                defaults.removeObject(forKey: secondURL)
            }
            defaults.set(second.description, forKey: secondDescription)
        } else {
            defaults.removeObject(forKey: secondTitle)
            defaults.removeObject(forKey: secondDate)
            defaults.removeObject(forKey: secondURL)
            defaults.removeObject(forKey: secondDescription)
        }

        if let third {
            defaults.set(third.title, forKey: thirdTitle)
            if let published = third.publishedAt {
                defaults.set(published.timeIntervalSince1970, forKey: thirdDate)
            } else {
                defaults.removeObject(forKey: thirdDate)
            }
            if let url = third.watchURL {
                defaults.set(url.absoluteString, forKey: thirdURL)
            } else {
                defaults.removeObject(forKey: thirdURL)
            }
            defaults.set(third.description, forKey: thirdDescription)
        } else {
            defaults.removeObject(forKey: thirdTitle)
            defaults.removeObject(forKey: thirdDate)
            defaults.removeObject(forKey: thirdURL)
            defaults.removeObject(forKey: thirdDescription)
        }

        if let fourth {
            defaults.set(fourth.title, forKey: fourthTitle)
            if let published = fourth.publishedAt {
                defaults.set(published.timeIntervalSince1970, forKey: fourthDate)
            } else {
                defaults.removeObject(forKey: fourthDate)
            }
            if let url = fourth.watchURL {
                defaults.set(url.absoluteString, forKey: fourthURL)
            } else {
                defaults.removeObject(forKey: fourthURL)
            }
            defaults.set(fourth.description, forKey: fourthDescription)
        } else {
            defaults.removeObject(forKey: fourthTitle)
            defaults.removeObject(forKey: fourthDate)
            defaults.removeObject(forKey: fourthURL)
            defaults.removeObject(forKey: fourthDescription)
        }

        // Write a downscaled thumbnail into the App Group container for the widget (offline rendering).
        Task.detached(priority: .utility) {
            if let thumb, let container = appGroupContainerURL() {
                do {
                    let req = ImageLoaderConfig.request(for: thumb)
                    let (data, response) = try await awaitURLData(req)
                    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let imageData = downscaleJPEGData(data: data, targetSize: CGSize(width: 320, height: 180), quality: 0.85) {
                        let fileURL = container.appendingPathComponent("mostRecentThumb.jpg")
                        try? FileManager.default.removeItem(at: fileURL)
                        try imageData.write(to: fileURL, options: .atomic)
                        defaults.set(fileURL.absoluteString, forKey: mostRecentThumbnailFile)
                        print("[App] Wrote widget thumbnail to:", fileURL.absoluteString, "exists:", FileManager.default.fileExists(atPath: fileURL.path))
                    } else {
                        defaults.removeObject(forKey: mostRecentThumbnailFile)
                    }
                } catch {
                    defaults.removeObject(forKey: mostRecentThumbnailFile)
                }

                // Write second most recent thumbnail
                if let second {
                    var sThumb: URL? = second.thumbnailURL ?? fallbackYouTubeThumbnail(from: second.watchURL)
                    if var t = sThumb, t.scheme?.lowercased() == "http" {
                        var comps = URLComponents(url: t, resolvingAgainstBaseURL: false)
                        comps?.scheme = "https"
                        if let https = comps?.url { t = https }
                        sThumb = t
                    }
                    if let sThumb, let container = appGroupContainerURL() {
                        do {
                            let req2 = ImageLoaderConfig.request(for: sThumb)
                            let (data2, response2) = try await awaitURLData(req2)
                            if let http2 = response2 as? HTTPURLResponse, (200..<300).contains(http2.statusCode), let imageData2 = downscaleJPEGData(data: data2, targetSize: CGSize(width: 320, height: 180), quality: 0.85) {
                                let fileURL2 = container.appendingPathComponent("secondThumb.jpg")
                                try? FileManager.default.removeItem(at: fileURL2)
                                try imageData2.write(to: fileURL2, options: .atomic)
                                defaults.set(fileURL2.absoluteString, forKey: secondThumbnailFile)
                            } else {
                                defaults.removeObject(forKey: secondThumbnailFile)
                            }
                        } catch {
                            defaults.removeObject(forKey: secondThumbnailFile)
                        }
                    } else {
                        defaults.removeObject(forKey: secondThumbnailFile)
                    }
                } else {
                    defaults.removeObject(forKey: secondThumbnailFile)
                }

                // Write third most recent thumbnail
                if let third {
                    var tThumb: URL? = third.thumbnailURL ?? fallbackYouTubeThumbnail(from: third.watchURL)
                    if var t = tThumb, t.scheme?.lowercased() == "http" {
                        var comps = URLComponents(url: t, resolvingAgainstBaseURL: false)
                        comps?.scheme = "https"
                        if let https = comps?.url { t = https }
                        tThumb = t
                    }
                    if let tThumb, let container = appGroupContainerURL() {
                        do {
                            let req3 = ImageLoaderConfig.request(for: tThumb)
                            let (data3, response3) = try await awaitURLData(req3)
                            if let http3 = response3 as? HTTPURLResponse, (200..<300).contains(http3.statusCode),
                               let imageData3 = downscaleJPEGData(data: data3, targetSize: CGSize(width: 320, height: 180), quality: 0.85) {
                                let fileURL3 = container.appendingPathComponent("thirdThumb.jpg")
                                try? FileManager.default.removeItem(at: fileURL3)
                                try imageData3.write(to: fileURL3, options: .atomic)
                                defaults.set(fileURL3.absoluteString, forKey: thirdThumbnailFile)
                            } else {
                                defaults.removeObject(forKey: thirdThumbnailFile)
                            }
                        } catch {
                            defaults.removeObject(forKey: thirdThumbnailFile)
                        }
                    } else {
                        defaults.removeObject(forKey: thirdThumbnailFile)
                    }
                } else {
                    defaults.removeObject(forKey: thirdThumbnailFile)
                }

                // Write fourth most recent thumbnail
                if let fourth {
                    var fThumb: URL? = fourth.thumbnailURL ?? fallbackYouTubeThumbnail(from: fourth.watchURL)
                    if var t = fThumb, t.scheme?.lowercased() == "http" {
                        var comps = URLComponents(url: t, resolvingAgainstBaseURL: false)
                        comps?.scheme = "https"
                        if let https = comps?.url { t = https }
                        fThumb = t
                    }
                    if let fThumb, let container = appGroupContainerURL() {
                        do {
                            let req4 = ImageLoaderConfig.request(for: fThumb)
                            let (data4, response4) = try await awaitURLData(req4)
                            if let http4 = response4 as? HTTPURLResponse, (200..<300).contains(http4.statusCode),
                               let imageData4 = downscaleJPEGData(data: data4, targetSize: CGSize(width: 320, height: 180), quality: 0.85) {
                                let fileURL4 = container.appendingPathComponent("fourthThumb.jpg")
                                try? FileManager.default.removeItem(at: fileURL4)
                                try imageData4.write(to: fileURL4, options: .atomic)
                                defaults.set(fileURL4.absoluteString, forKey: fourthThumbnailFile)
                            } else {
                                defaults.removeObject(forKey: fourthThumbnailFile)
                            }
                        } catch {
                            defaults.removeObject(forKey: fourthThumbnailFile)
                        }
                    } else {
                        defaults.removeObject(forKey: fourthThumbnailFile)
                    }
                } else {
                    defaults.removeObject(forKey: fourthThumbnailFile)
                }

                defaults.synchronize()
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadTimelines(ofKind: "MeowbahMostRecentVideoWidget")
                #endif
            } else {
                defaults.removeObject(forKey: mostRecentThumbnailFile)
                defaults.removeObject(forKey: secondThumbnailFile)
                defaults.removeObject(forKey: thirdThumbnailFile)
                defaults.removeObject(forKey: fourthThumbnailFile)
                defaults.synchronize()
            }
        }

        // Force a flush so the widget sees updates immediately.
        // (Moved inside Task above because of async)
    }

    private static func fallbackYouTubeThumbnail(from watchURL: URL?) -> URL? {
        guard let url = watchURL else { return nil }

        // youtu.be/<id>
        if url.host?.contains("youtu.be") == true {
            if let id = url.pathComponents.dropFirst().first {
                return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
            }
        }

        // youtube.com/watch?v=<id>
        if url.host?.contains("youtube.com") == true {
            if url.path == "/watch" {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let id = comps?.queryItems?.first(where: { $0.name == "v" })?.value
                return id.flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/hqdefault.jpg") }
            }

            // youtube.com/shorts/<id>
            if url.pathComponents.contains("shorts"),
               let idx = url.pathComponents.firstIndex(of: "shorts"),
               url.pathComponents.indices.contains(idx + 1) {
                let id = url.pathComponents[idx + 1]
                return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
            }
        }

        return nil
    }

    private static func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    private static func awaitURLData(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await ImageLoaderConfig.session.data(for: request)
    }

    #if canImport(UIKit)
    private static func downscaleJPEGData(data: Data, targetSize: CGSize, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
    #else
    private static func downscaleJPEGData(data: Data, targetSize: CGSize, quality: CGFloat) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let dest = NSImage(size: targetSize)
        dest.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        dest.unlockFocus()
        guard let tiff = dest.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else { return nil }
        return jpg
    }
    #endif
}
#endif

// MARK: - Local Notifications

#if !os(tvOS)
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

    // Persist seen IDs so background refresh can detect new videos even when the app was closed.
    private static let knownIDsKey = "meowbah.knownVideoIDs"

    static func loadKnownIDs() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: knownIDsKey) ?? []
        return Set(arr)
    }

    static func saveKnownIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: knownIDsKey)
    }
}
#endif

// MARK: - Background refresh (best-effort)
// NOTE: iOS/visionOS background execution is not guaranteed every 5 minutes.
// We request an earliest run time of 5 minutes; the system decides the actual schedule.
#if !os(tvOS)
private enum VideoBackgroundRefresh {
    // Add this identifier to Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let taskIdentifier = "com.meowbah.refreshVideos"
    private static var didRegister = false

    static func register() {
        if didRegister { return }
        didRegister = true

        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleAppRefresh(task: refreshTask)
        }
        #endif
    }

    static func scheduleNextRefresh() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Ask for 5 minutes; the system may run later.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Ignore; system may reject if not permitted or too frequent.
        }
        #endif
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        // Always schedule the next one.
        scheduleNextRefresh()

        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached(priority: .utility) {
                defer { semaphore.signal() }
                await checkForNewVideosAndNotify()
            }
            // Give the async work time; the task expiration handler will cancel.
            _ = semaphore.wait(timeout: .now() + 25)
        }

        task.expirationHandler = {
            opQueue.cancelAllOperations()
        }

        operation.completionBlock = {
            let success = !operation.isCancelled
            task.setTaskCompleted(success: success)
        }

        opQueue.addOperation(operation)
    }

    @MainActor
    private static func checkForNewVideosAndNotify() async {
        // Ensure notification permissions are requested.
        await NotificationManager.requestAuthorizationIfNeeded()

        do {
            // This uses the same source as the app UI.
            let fetched = try await YouTubeAPIClient.shared.fetchLatestVideos(maxResults: 25)
            let fetchedIDs = Set(fetched.map { $0.id })

            var known = NotificationManager.loadKnownIDs()
            // Detect new IDs
            let newIDs = fetchedIDs.subtracting(known)

            if !newIDs.isEmpty {
                // Notify for new videos (most recent first)
                let newVideos = fetched
                    .filter { newIDs.contains($0.id) }
                    .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

                for video in newVideos {
                    await NotificationManager.scheduleNewVideoNotification(video: video)
                }
            }

            // Update known set to the fetched set (keeps it bounded)
            known = fetchedIDs
            NotificationManager.saveKnownIDs(known)
        } catch {
            // Ignore failures; we'll try again next time.
        }
    }
}
#endif

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
        .modifier(ThumbnailFrame(size: size))
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

// Added per instructions for flexible sizing in ThumbnailView
private struct ThumbnailFrame: ViewModifier {
    let size: CGSize
    func body(content: Content) -> some View {
        if size.width == 1 && size.height == 1 {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content.frame(width: size.width, height: size.height)
        }
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

// MARK: - QR Code helper

import CoreImage
import CoreImage.CIFilterBuiltins

private struct QRCodeView: View {
    let url: URL
    var body: some View {
        if let image = generateQRCode(from: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = outputImage.transformed(by: transform)
        if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
}

// MARK: - Platform-safe system colors

private enum PlatformColors {
    static var secondaryBackground: Color {
        #if os(tvOS)
        return Color.black.opacity(0.22)
        #elseif canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }
}

// MARK: - View

// MARK: - Layout switching

private enum LayoutChoice {
    case list
    case grid(columns: Int)

    static func forWidth(_ width: CGFloat) -> LayoutChoice {
        #if os(tvOS)
        // tvOS needs larger tiles; keep columns low to avoid clutter.
        if width < 1300 {
            return .grid(columns: 2)
        } else {
            return .grid(columns: 3)
        }
        #else
        switch width {
        case ..<600: return .list
        case 600..<900: return .grid(columns: 2)
        default: return .grid(columns: 3)
        }
        #endif
    }
}

struct VideosView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var isRefreshing = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var quotaBannerMessage: String?
    @State private var videos: [Video] = []
    #if os(iOS)
    @State private var selectedVideoSheet: Video?
    #endif

    #if os(tvOS)
    @State private var selectedVideo: Video?
    #endif
    
    #if os(visionOS)
    @State private var selectedVideoVision: Video?
    #endif

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

    #if !os(tvOS)
        NavigationStack {
            ZStack {
                // Always paint the themed background and ignore safe areas to prevent black borders
                Color(.systemBackground)
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
#if os(visionOS)
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search videos", text: $searchText)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(PlatformColors.secondaryBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(PlatformColors.secondaryBackground.opacity(0.0), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                            Divider()
                                .opacity(0.25)
                                .padding(.horizontal, 16)
                        }
#endif
                        if let banner = quotaBannerMessage, !banner.isEmpty {
                            Text(banner)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.primary.opacity(0.9))
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
                                errorState(message: errorMessage)
                            } else {
                                content(layout: layout)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Videos")
            .navigationDestination(for: Video.self) { video in
                VideoDetailView(video: video)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await loadVideos(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Menu {
                    Picker("Sort by", selection: $selectedSort) {
                        Text("Name").tag(SortOption.name)
                        Text("Date").tag(SortOption.date)
                        Text("Duration").tag(SortOption.duration)
                    }
                    if selectedSort == .duration {
                        Toggle(isOn: $durationAscending) {
                            Text("Shortest first")
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .task {
            if videos.isEmpty {
                await loadVideos(force: false)
            }
#if !os(tvOS)
            // Register and schedule best-effort background refresh.
            VideoBackgroundRefresh.register()
            VideoBackgroundRefresh.scheduleNextRefresh()
#endif
        }
        .refreshable {
            await loadVideos(force: true)
        }
#if os(iOS) && !os(visionOS)
        .sheet(item: $selectedVideoSheet) { vid in
            NavigationStack {
                VideoDetailView(video: vid)
            }
        }
#endif
#if os(visionOS)
        .sheet(item: $selectedVideoVision) { vid in
            NavigationStack {
                VideoDetailView(video: vid)
            }
        }
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
#if os(iOS) || os(macOS)
        .tint(Color.primary)
#endif
#else
        ZStack {
            // Always paint the background and ignore safe areas to prevent black borders
#if os(tvOS)
            Color.black
                .ignoresSafeArea()
#else
            Color(.systemBackground)
                .ignoresSafeArea()
#endif

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
#if os(tvOS)
                    HStack(spacing: 16) {
                        Button {
                            Task { await loadVideos(force: true) }
                        } label: {
                            Text("Refresh").bold()
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            Picker("Sort by", selection: $selectedSort) {
                                Text("Name").tag(SortOption.name)
                                Text("Date").tag(SortOption.date)
                                Text("Duration").tag(SortOption.duration)
                            }
                            if selectedSort == .duration {
                                Toggle(isOn: $durationAscending) {
                                    Text("Shortest first")
                                }
                            }
                        } label: {
                            Text("Sort")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
#endif

                    if let banner = quotaBannerMessage, !banner.isEmpty {
                        Text(banner)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color.primary.opacity(0.9))
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
                            errorState(message: errorMessage)
                        } else {
                            content(layout: layout)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            if videos.isEmpty {
                await loadVideos(force: false)
            }
        }
#if os(tvOS)
        .sheet(item: $selectedVideo) { vid in
            VideoDetailView(video: vid)
        }
#endif
#endif
    }


    @ViewBuilder
    private func content(layout: LayoutChoice) -> some View {
        switch layout {
        case .list:
            List {
                ForEach(filteredVideos) { video in
#if os(tvOS)
                    Button {
                        selectedVideo = video
                    } label: {
                        VideoRow(video: video)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
#else
#if os(visionOS)
Button {
    selectedVideoVision = video
} label: {
    VideoRow(video: video)
}
.buttonStyle(.plain)
.listRowBackground(Color.clear)
#else
#if os(iOS)
Button {
    selectedVideoSheet = video
} label: {
    VideoRow(video: video)
}
.buttonStyle(.plain)
.listRowBackground(Color.clear)
#else
NavigationLink(value: video) {
    VideoRow(video: video)
}
.listRowBackground(Color.clear)
#endif
#endif
#endif
                }
            }
            .listStyle(.plain)
#if !os(tvOS)
            .scrollContentBackground(.hidden)
#endif
#if !os(tvOS)
            .listRowSeparator(.hidden)
#endif
#if !os(visionOS) && !os(tvOS)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search videos")
#endif

        case .grid(let cols):
            let gridSpacing: CGFloat = {
                #if os(tvOS)
                return 48
                #else
                return 16
                #endif
            }()

            let gridColumns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: cols)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(filteredVideos) { video in
                        #if os(tvOS)
                        Button {
                            selectedVideo = video
                        } label: {
                            VideosGridItem(video: video)
                        }
                        .buttonStyle(.plain)
                        #else
                        #if os(visionOS)
                        Button {
                            selectedVideoVision = video
                        } label: {
                            VideosGridItem(video: video)
                        }
                        .buttonStyle(.plain)
                        #else
                        #if os(iOS)
                        Button {
                            selectedVideoSheet = video
                        } label: {
                            VideosGridItem(video: video)
                        }
                        .buttonStyle(.plain)
                        #else
                        NavigationLink(value: video) {
                            VideosGridItem(video: video)
                        }
                        .buttonStyle(.plain)
                        #endif
                        #endif
                        #endif
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
                #else
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                #endif
            }
#if !os(visionOS) && !os(tvOS)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search videos")
#endif
        }
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
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
                    .foregroundStyle(Color.primary)
                    .padding(.top, -6)
            }
#else
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.primary)
                .padding(.top, -6)
#endif

            Text("Failed to load videos")
                .font(.title2).bold()
                .foregroundStyle(Color.primary)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 20)

            Button {
                Task { await loadVideos(force: true) }
            } label: {
                Text("Retry").bold()
            }
            .tint(Color.primary)
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
        defer { Task { await MainActor.run { self.isLoading = false } } }

        do {
            let fetched = try await YouTubeAPIClient.shared.fetchLatestVideos(maxResults: 25)
            await MainActor.run {
                self.videos = fetched
                self.knownVideoIDs = Set(fetched.map { $0.id })
#if !os(tvOS)
                NotificationManager.saveKnownIDs(self.knownVideoIDs)
                MostRecentVideoWidgetWriter.save(from: fetched)
#endif
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
    @Environment(\.colorScheme) private var colorScheme
    let video: Video

    var body: some View {

        HStack(spacing: 12) {
            thumbnail(size: CGSize(width: 96, height: 56), corner: 12)
            texts()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color.clear)
    }

    private func thumbnail(size: CGSize, corner: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(PlatformColors.secondaryBackground)
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

    private func texts() -> some View {
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
                                .fill(PlatformColors.secondaryBackground.opacity(0.8))
                        )
                        .foregroundStyle(Color.primary)
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
    @Environment(\.colorScheme) private var colorScheme
    let video: Video

    private let tvOSCellWidth: CGFloat = 420
    private let tvOSCellHeight: CGFloat = 236

    var body: some View {

        #if os(tvOS)
        tvOSGridItem()
        #else
        nonTVOSGridItem()
        #endif
    }

    // MARK: - tvOS

    private func tvOSThumbnail() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformColors.secondaryBackground)
                .frame(width: tvOSCellWidth, height: tvOSCellHeight)

            if let url = video.thumbnailURL {
                ThumbnailView(url: url, size: CGSize(width: tvOSCellWidth, height: tvOSCellHeight), cornerRadius: 12)
            } else {
                Image(systemName: "play.rectangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: tvOSCellWidth, height: tvOSCellHeight)
                    .foregroundStyle(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
    }

    private func tvOSOverlay() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.title)
                .font(.headline)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)

            HStack(spacing: 8) {
                if !video.formattedDuration.isEmpty {
                    Text(video.formattedDuration)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                        )
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }

                if !video.publishedAtFormatted.isEmpty {
                    Text(video.publishedAtFormatted)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tvOSGridItem() -> some View {
        ZStack(alignment: .bottomLeading) {
            tvOSThumbnail()
            tvOSOverlay()
        }
        .frame(width: tvOSCellWidth, height: tvOSCellHeight)
        .clipped()
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    // MARK: - iOS/macOS

    private func nonTVOSThumbnail() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformColors.secondaryBackground)
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
        .accessibilityHidden(true)
    }

    private func nonTVOSTexts() -> some View {
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
                                .fill(PlatformColors.secondaryBackground.opacity(0.8))
                        )
                        .foregroundStyle(Color.primary)
                }

                if !video.publishedAtFormatted.isEmpty {
                    Text(video.publishedAtFormatted)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    private func nonTVOSGridItem() -> some View {
        HStack(spacing: 12) {
            nonTVOSThumbnail()
            nonTVOSTexts()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail View

private struct VideoDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let video: Video
    @State private var showSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // First section: Thumbnail, title, date
                Section {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PlatformColors.secondaryBackground)
                        if let url = video.thumbnailURL {
                            ThumbnailView(url: url, size: CGSize(width: 1, height: 1), cornerRadius: 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        Image(systemName: "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .allowsHitTesting(false)
#if os(tvOS)
                    .focusable(false)
#endif
                    .frame(maxWidth: .infinity)
                    
                    Text(video.title)
                        .font(.title2).bold()
                        .foregroundStyle(Color.primary)
#if os(tvOS)
                        .focusable(true)
#endif
                        .multilineTextAlignment(.leading)
                    if !video.publishedAtFormatted.isEmpty {
                        Text("Posted \(video.publishedAtFormatted)")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
#if os(tvOS)
                            .focusable(true)
#endif
                    }
                }
                // Description section
                Section {
                    if !video.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(video.description.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Play button section
                if let url = video.watchURL {
                    playButton(url: url)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
#if os(tvOS)
            .focusSection()
#endif
        }
        .scrollIndicators(.visible)
        .scrollDisabled(false)
#if os(tvOS)
        .background(Color.black)
#else
        .background(Color(.systemBackground))
#endif
        .navigationTitle("Video")
        #if canImport(SafariServices) && canImport(UIKit) && !os(tvOS)
        .navigationDestination(for: URL.self) { url in
            YouTubeSafariView(url: url)
        }
        #endif
#if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if let url = video.watchURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
#endif
    }

    private func playButtonLabel() -> some View {
        HStack {
            Image(systemName: "play.circle.fill")
            Text("Play on YouTube").bold()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.15))
        )
        .foregroundStyle(Color.primary)
    }

    @ViewBuilder
    private func playButton(url: URL) -> some View {
        #if canImport(SafariServices) && canImport(UIKit) && !os(tvOS)
        NavigationLink(value: url) {
            playButtonLabel()
        }
        #elseif os(tvOS)
        Button {
            showSafari = true
        } label: {
            playButtonLabel()
        }
        .sheet(isPresented: $showSafari) {
            VStack(spacing: 24) {
                Text("Scan to watch on your phone")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                QRCodeView(url: url)
                    .frame(width: 400, height: 400)
                    .padding()
                Text(url.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        #elseif canImport(UIKit)
        Button {
            UIApplication.shared.open(url)
        } label: {
            playButtonLabel()
        }
        #elseif canImport(AppKit)
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            playButtonLabel()
        }
        #else
        Button { } label: {
            playButtonLabel()
        }
        #endif
    }
}

// MARK: - Safari wrapper

#if canImport(SafariServices) && canImport(UIKit)
private struct YouTubeSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        #if !os(visionOS)
        vc.preferredBarTintColor = UIColor.clear
        #endif
        #if !os(visionOS)
        vc.preferredControlTintColor = UIColor.label
        #endif
        #if !os(visionOS)
        vc.dismissButtonStyle = .close
        #endif
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
#endif

#Preview {
    VideosView()
}


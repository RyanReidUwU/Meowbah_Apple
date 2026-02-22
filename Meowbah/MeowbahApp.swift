//
//  MeowbahApp.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
#if canImport(WatchConnectivity) && !os(tvOS)
import WatchConnectivity
#endif

@main
struct MeowbahApp: App {

    #if canImport(WatchConnectivity) && !os(tvOS)
    private let watchSessionManager = PhoneWatchSessionManager.shared
    #endif

    init() {
        #if canImport(WatchConnectivity) && !os(tvOS)
        watchSessionManager.activateIfPossible()
        #endif

        #if canImport(UIKit) && !os(tvOS)
        // Make TabBar fully transparent across styles (iPhone/iPad, standard/scrollEdge)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Make NavigationBar fully transparent across styles
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        #endif

        // Register BGTask identifiers (only where BackgroundTasks is available)
        #if canImport(BackgroundTasks)
        BackgroundRefreshManager.shared.register()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Use the system background now that ThemeManager is removed.
                #if os(tvOS)
                // tvOS doesn't expose UIColor.systemBackground; use a neutral background
                Color.black.opacity(0.95).ignoresSafeArea()
                #elseif canImport(UIKit)
                Color(UIColor.systemBackground).ignoresSafeArea()
                #else
                // macOS/AppKit fallback
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                #endif

                RootTabView()
                    .task {
                        #if canImport(UserNotifications)
                        // Ask for notification permission once (optional)
                        await NotificationHelper.requestAuthorizationIfNeeded()
                        #endif
                    }
            }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Schedule background refresh when app goes to background
                #if canImport(BackgroundTasks)
                BackgroundRefreshManager.shared.scheduleNextRefresh()
                #endif
            }
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}


// MARK: - MeowTalk phrase sharing (iPhone -> Watch)

/// Call `MeowTalkSharedState.setCurrentPhrase(...)` whenever the on-screen MeowTalk phrase changes.
/// The watch reads this value via WatchConnectivity (`requestMeowTalk`).
enum MeowTalkSharedState {
    static let appGroupID = "group.meowbah"
    static let key = "meowtalk.currentPhrase"

    static func setCurrentPhrase(_ phrase: String) {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(trimmed, forKey: key)
    }

    static func currentPhrase() -> String {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        return defaults.string(forKey: key) ?? ""
    }
}

 
#if canImport(WatchConnectivity) && !os(tvOS)
// MARK: - WatchConnectivity (iPhone side)

final class PhoneWatchSessionManager: NSObject {
    static let shared = PhoneWatchSessionManager()

    private override init() {
        super.init()
    }

    func activateIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

extension PhoneWatchSessionManager: WCSessionDelegate {

    private func deriveYouTubeThumbnailURL(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "" }
        let host = (url.host ?? "").lowercased()

        var videoID: String? = nil
        if host.contains("youtube.com") {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            videoID = comps?.queryItems?.first(where: { $0.name == "v" })?.value
        } else if host == "youtu.be" {
            videoID = url.pathComponents.last
        }

        guard let id = videoID, !id.isEmpty else { return "" }
        return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
    }

    private func jpegBase64ForImage(named name: String) -> String {
        #if canImport(UIKit)
        guard let image = UIImage(named: name) else { return "" }

        // WCSession reply payloads are small; base64 adds ~33% overhead.
        // Keep the JPEG under this cap.
        let maxJPEGBytes = 55_000
        let sideCandidates: [CGFloat] = [120, 96, 80]
        let qualities: [CGFloat] = [0.45, 0.35, 0.28, 0.22]

        for side in sideCandidates {
            let targetSize = CGSize(width: side, height: side)
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

            let scaled = renderer.image { _ in
                // Aspect-fill into a square.
                let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
                let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let origin = CGPoint(
                    x: (targetSize.width - scaledSize.width) / 2,
                    y: (targetSize.height - scaledSize.height) / 2
                )
                image.draw(in: CGRect(origin: origin, size: scaledSize))
            }

            for q in qualities {
                if let data = scaled.jpegData(compressionQuality: q), data.count <= maxJPEGBytes {
                    return data.base64EncodedString()
                }
            }
        }

        // Last resort: tiny + heavy compression.
        let targetSize = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let scaled = renderer.image { _ in
            let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        guard let data = scaled.jpegData(compressionQuality: 0.18) else { return "" }
        return data.base64EncodedString()
        #else
        return ""
        #endif
    }

    private func jpegBase64ForImageAspectFit(named name: String) -> String {
        #if canImport(UIKit)
        guard let image = UIImage(named: name) else { return "" }

        let maxJPEGBytes = 65_000
        let sideCandidates: [CGFloat] = [160, 140, 120]
        let qualities: [CGFloat] = [0.45, 0.35, 0.28, 0.22]

        func renderAspectFit(maxSide: CGFloat) -> UIImage {
            let maxDim = max(image.size.width, image.size.height)
            let scale = min(maxSide / maxDim, 1.0)
            let scaledSize = CGSize(
                width: max(1, image.size.width * scale),
                height: max(1, image.size.height * scale)
            )

            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
        }

        for side in sideCandidates {
            let scaled = renderAspectFit(maxSide: side)
            for q in qualities {
                if let data = scaled.jpegData(compressionQuality: q), data.count <= maxJPEGBytes {
                    return data.base64EncodedString()
                }
            }
        }

        // Last resort: very small + heavy compression.
        let tiny = renderAspectFit(maxSide: 100)
        guard let data = tiny.jpegData(compressionQuality: 0.18) else { return "" }
        return data.base64EncodedString()
        #else
        return ""
        #endif
    }

    private func bestMerchImageName(for id: String) -> String {
        // Merch assets in the iOS app are named by `MerchItem.imageName`.
        if let item = SampleMerchData.items.first(where: { $0.id == id }) {
            return item.imageName
        }
        return id
    }

    private func bestArtImageName(for id: String) -> String {
        // Prefer the published catalog if it includes imageName.
        // If not present, fall back to the built-in fallback list.
        if let item = loadArtPayload().first(where: { ($0["id"] as? String) == id }),
           let name = item["imageName"] as? String,
           !name.isEmpty {
            return name
        }

        if let item = fallbackArtPayloadFromApp().first(where: { ($0["id"] as? String) == id }),
           let name = item["imageName"] as? String,
           !name.isEmpty {
            return name
        }

        // Common convention: ids like "art_quran" -> asset "quran"
        if id.hasPrefix("art_") {
            return String(id.dropFirst(4))
        }

        return id
    }

    private func loadArtPayload() -> [[String: Any]] {
        // Phone app can publish art items as JSON into the shared App Group defaults.
        // Key: "art.catalogJSON"
        // Expected JSON shape:
        // [{"id":"...","title":"...","description":"...","imageURL":"...","url":"..."}, ...]
        let defaults = UserDefaults(suiteName: "group.meowbah") ?? .standard
        let json = defaults.string(forKey: "art.catalogJSON") ?? ""
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return [] }

        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }

        return arr.compactMap { dict in
            guard let id = dict["id"] as? String, !id.isEmpty else { return nil }
            let title = (dict["title"] as? String) ?? ""
            let desc = (dict["description"] as? String) ?? ""
            let imageName = (dict["imageName"] as? String) ?? ""
            let imageURL = (dict["imageURL"] as? String) ?? ""
            let url = (dict["url"] as? String) ?? ""
            return [
                "id": id,
                "title": title,
                "description": desc,
                "imageName": imageName,
                "imageURL": imageURL,
                "url": url
            ]
        }
    }

    private func fallbackArtPayloadFromApp() -> [[String: Any]] {
        // Fallback list sourced from the phone app's bundled art assets.
        // This prevents the watch from showing an empty state if the App Group JSON hasn’t been published yet.
        // NOTE: Ensure these image names exist in the iOS asset catalog.
        return [
            ["id": "art_quran", "title": "Meow Reads The Quran", "description": "Animation", "imageName": "quran", "imageURL": "", "url": ""],
            ["id": "art_friends", "title": "Meow and CommotionSickness", "description": "Commotion", "imageName": "friends", "imageURL": "", "url": ""],
            ["id": "art_girlgirl", "title": "HEAVY METAL LOVER Animation", "description": "Animation", "imageName": "girlgirl", "imageURL": "", "url": ""],
            ["id": "art_hikari", "title": "Hikari from Blue Archive", "description": "Blue Archive", "imageName": "hikari", "imageURL": "", "url": ""],
            ["id": "art_meowgod", "title": "Holy Meowgod From Above!!", "description": "Art", "imageName": "meowgod", "imageURL": "", "url": ""],
            ["id": "art_refsheet", "title": "Meowbah's Reference Sheet", "description": "Art", "imageName": "refsheet", "imageURL": "", "url": ""]
        ]
    }



    // Reply messages
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {

        guard let type = message["type"] as? String else {
            replyHandler([:])
            return
        }

        switch type {
        case "requestMerch":
            // Serve merch directly from the phone app's current catalog.
            // We include an imageName so the watch can ask the phone for the actual image bytes.
            let merchItems: [[String: Any]] = SampleMerchData.items.map { item in
                [
                    "id": item.id,
                    "title": item.name,
                    "price": item.price,
                    "description": item.description,
                    "imageName": item.imageName,
                    "imageURL": "",
                    "url": item.storeUrl
                ]
            }
            replyHandler(["merch": merchItems])

        case "requestArt":
            let items = loadArtPayload()
            replyHandler(["art": items.isEmpty ? fallbackArtPayloadFromApp() : items])

        case "requestArtImage":
            let id = (message["id"] as? String) ?? ""
            let requestedName = (message["imageName"] as? String) ?? ""

            var b64 = ""
            if !requestedName.isEmpty {
                b64 = jpegBase64ForImage(named: requestedName)
            }
            if b64.isEmpty {
                b64 = jpegBase64ForImage(named: bestArtImageName(for: id))
            }

            replyHandler([
                "id": id,
                "imageBase64": b64,
                "mime": "image/jpeg"
            ])

        case "requestArtImageFull":
            let id = (message["id"] as? String) ?? ""
            let requestedName = (message["imageName"] as? String) ?? ""

            var b64 = ""
            if !requestedName.isEmpty {
                b64 = jpegBase64ForImageAspectFit(named: requestedName)
            }
            if b64.isEmpty {
                b64 = jpegBase64ForImageAspectFit(named: bestArtImageName(for: id))
            }

            replyHandler([
                "id": id,
                "imageBase64": b64,
                "mime": "image/jpeg"
            ])

        case "requestMerchImage":
            // Watch requests a single merch image by id (which we also use as imageName).
            let id = (message["id"] as? String) ?? ""
            let requestedName = (message["imageName"] as? String) ?? ""

            var b64 = ""
            if !requestedName.isEmpty {
                b64 = jpegBase64ForImage(named: requestedName)
            }
            if b64.isEmpty {
                b64 = jpegBase64ForImage(named: bestMerchImageName(for: id))
            }

            replyHandler([
                "id": id,
                "imageBase64": b64,
                "mime": "image/jpeg"
            ])

        case "requestMeowTalk":
            // The phone app should keep the currently displayed phrase in the App Group.
            // This allows the watch to mirror what's on-screen.
            let defaults = UserDefaults(suiteName: "group.meowbah") ?? .standard
            let phrase = defaults.string(forKey: "meowtalk.currentPhrase")
                ?? defaults.string(forKey: "meowtalk.current")
                ?? defaults.string(forKey: "meowtalk.phrase")
                ?? ""
            replyHandler([
                "phrase": phrase
            ])

        case "requestVideos":
            // Attempt to read from UserDefaults/App Group where your widget writer stores data.
            let defaults = UserDefaults(suiteName: "group.meowbah") ?? .standard

            func read(prefix: String) -> [String: Any]? {
                guard let title = defaults.string(forKey: "\(prefix).title") else { return nil }
                let url = defaults.string(forKey: "\(prefix).url") ?? ""
                let ts = defaults.double(forKey: "\(prefix).date")
                let desc = defaults.string(forKey: "\(prefix).description") ?? ""
                let explicitThumb = defaults.string(forKey: "\(prefix).thumbnailURL") ?? ""
                let thumb = !explicitThumb.isEmpty ? explicitThumb : deriveYouTubeThumbnailURL(from: url)

                let id = url.isEmpty ? title : url
                var dict: [String: Any] = [
                    "id": id,
                    "title": title,
                    "url": url,
                    "description": desc,
                    "thumbnailURL": thumb
                ]
                if ts > 0 {
                    dict["publishedAt"] = ts
                }
                return dict
            }

            var items: [[String: Any]] = []
            if let a = read(prefix: "videos.mostRecent") { items.append(a) }
            if let b = read(prefix: "videos.second") { items.append(b) }
            if let c = read(prefix: "videos.third") { items.append(c) }
            if let d = read(prefix: "videos.fourth") { items.append(d) }

            replyHandler(["videos": items])

        default:
            replyHandler([:])
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // No-op
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // No-op
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after switching to a new paired watch
        session.activate()
    }
}
#endif

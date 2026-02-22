import SwiftUI
import Combine
import WatchConnectivity
#if canImport(UIKit)
import UIKit

#endif

private let meowPinkBackground = Color(red: 1.0, green: 0.4, blue: 0.7)
    .opacity(0.30)
    .gradient


private let meowPinkTop = Color(red: 1.0, green: 0.4, blue: 0.7).opacity(0.30)
private let meowPinkBottom = Color(red: 1.0, green: 0.4, blue: 0.7).opacity(0.10)

private func meowTempJPEGURL(id: String, data: Data) -> URL? {
    let safeID = id.isEmpty ? UUID().uuidString : id
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("meowbah-art-\(safeID).jpg")
    do {
        // Overwrite to ensure it matches the latest image.
        try data.write(to: url, options: [.atomic])
        return url
    } catch {
        return nil
    }
}

enum Item: String, CaseIterable, Hashable {
    case videos
    case merch
    case art
    case meowTalk

    var title: String {
        switch self {
        case .videos: return "Videos"
        case .merch: return "Merch"
        case .art: return "Art"
        case .meowTalk: return "MeowTalk"
        }
    }

    var systemImage: String {
        switch self {
        case .videos: return "play.rectangle.fill"
        case .merch: return "bag.fill"
        case .art: return "paintpalette.fill"
        case .meowTalk: return "message.fill"
        }
    }
}

struct WatchVideoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let publishedAt: Date?
    let urlString: String
    let description: String
    let thumbnailURLString: String
}

struct WatchMerchItem: Identifiable, Hashable {
    let id: String
    let title: String
    let price: String
    let description: String
    let imageName: String
    let imageURLString: String
    let urlString: String
}

struct WatchArtItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let imageName: String
    let imageURLString: String
    let urlString: String
}

@MainActor
final class WatchVideoSync: NSObject, ObservableObject {
    static let shared = WatchVideoSync()

    @Published var videos: [WatchVideoItem] = []
    @Published var lastError: String? = nil
    @Published var isLoading: Bool = false

    private override init() {
        super.init()
        activateIfPossible()
    }

    func activateIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func refresh() {
        guard WCSession.isSupported() else {
            lastError = "WatchConnectivity not supported"
            return
        }
        let session = WCSession.default
        isLoading = true
        lastError = nil

        // If phone isn't reachable, we can still try the last applicationContext in `sessionDidBecomeInactive` etc.
        // For MVP, show a helpful message.
        guard session.isReachable else {
            isLoading = false
            lastError = "Open Meowbah on your iPhone to sync."
            return
        }

        session.sendMessage(["type": "requestVideos"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.isLoading = false
                self?.applyReply(reply)
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }


    private func applyReply(_ reply: [String: Any]) {
        guard let raw = reply["videos"] as? [[String: Any]] else {
            lastError = "Invalid response from iPhone"
            return
        }

        let parsed: [WatchVideoItem] = raw.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            let title = (dict["title"] as? String) ?? "Untitled"
            let urlString = (dict["url"] as? String) ?? ""
            let description = (dict["description"] as? String) ?? ""
            let thumbnailURLString = (dict["thumbnailURL"] as? String) ?? ""
            let ts = dict["publishedAt"] as? Double
            let date = ts.map { Date(timeIntervalSince1970: $0) }
            return WatchVideoItem(
                id: id,
                title: title,
                publishedAt: date,
                urlString: urlString,
                description: description,
                thumbnailURLString: thumbnailURLString
            )
        }

        videos = parsed
        if videos.isEmpty {
            lastError = "No videos available"
        }
    }
}

@MainActor
final class WatchMerchSync: NSObject, ObservableObject {
    static let shared = WatchMerchSync()

    @Published var items: [WatchMerchItem] = []
    @Published var lastError: String? = nil
    @Published var isLoading: Bool = false

    private override init() {
        super.init()
        activateIfPossible()
    }

    func activateIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func refresh() {
        guard WCSession.isSupported() else {
            lastError = "WatchConnectivity not supported"
            return
        }
        let session = WCSession.default
        isLoading = true
        lastError = nil

        guard session.isReachable else {
            isLoading = false
            lastError = "Open Meowbah on your iPhone to sync."
            return
        }

        session.sendMessage(["type": "requestMerch"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.isLoading = false
                self?.applyReply(reply)
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }


    private func applyReply(_ reply: [String: Any]) {
        guard let raw = reply["merch"] as? [[String: Any]] else {
            lastError = "Invalid response from iPhone"
            items = []
            return
        }

        let parsed: [WatchMerchItem] = raw.compactMap { dict in
            guard let id = dict["id"] as? String, !id.isEmpty else { return nil }
            let title = (dict["title"] as? String) ?? ""
            let price = (dict["price"] as? String) ?? ""
            let description = (dict["description"] as? String) ?? ""
            let imageName = (dict["imageName"] as? String) ?? ""
            let imageURLString = (dict["imageURL"] as? String) ?? ""
            let urlString = (dict["url"] as? String) ?? ""
            return WatchMerchItem(
                id: id,
                title: title,
                price: price,
                description: description,
                imageName: imageName,
                imageURLString: imageURLString,
                urlString: urlString
            )
        }

        items = parsed
        if items.isEmpty {
            lastError = "No merch available"
        }
    }
}

@MainActor
final class WatchArtSync: NSObject, ObservableObject {
    static let shared = WatchArtSync()

    @Published var items: [WatchArtItem] = []
    @Published var lastError: String? = nil
    @Published var isLoading: Bool = false

    private override init() {
        super.init()
        activateIfPossible()
    }

    func activateIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func refresh() {
        guard WCSession.isSupported() else {
            lastError = "WatchConnectivity not supported"
            return
        }
        let session = WCSession.default
        isLoading = true
        lastError = nil

        guard session.isReachable else {
            isLoading = false
            lastError = "Open Meowbah on your iPhone to sync."
            return
        }

        session.sendMessage(["type": "requestArt"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.isLoading = false
                self?.applyReply(reply)
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }


    private func applyReply(_ reply: [String: Any]) {
        guard let raw = reply["art"] as? [[String: Any]] else {
            lastError = "Invalid response from iPhone"
            items = []
            return
        }

        let parsed: [WatchArtItem] = raw.compactMap { dict in
            guard let id = dict["id"] as? String, !id.isEmpty else { return nil }
            let title = (dict["title"] as? String) ?? "Art"
            let description = (dict["description"] as? String) ?? ""
            let imageName = (dict["imageName"] as? String) ?? ""
            let imageURLString = (dict["imageURL"] as? String) ?? ""
            let urlString = (dict["url"] as? String) ?? ""
            return WatchArtItem(
                id: id,
                title: title,
                description: description,
                imageName: imageName,
                imageURLString: imageURLString,
                urlString: urlString
            )
        }

        items = parsed
        if items.isEmpty {
            lastError = "No art available"
        }
    }
}

@MainActor
final class WatchArtImageStore: ObservableObject {
    static let shared = WatchArtImageStore()

    @Published private(set) var imagesByID: [String: UIImage] = [:]
    @Published private(set) var fullImagesByID: [String: UIImage] = [:]
    @Published var lastError: String? = nil
    private var inFlight: Set<String> = []

    private init() {}

    func image(for id: String) -> UIImage? {
        imagesByID[id]
    }

    func fullImage(for id: String) -> UIImage? {
        fullImagesByID[id]
    }

    func fetchIfNeeded(id: String, imageName: String) {
        #if canImport(UIKit)
        guard imagesByID[id] == nil else { return }
        guard !inFlight.contains(id) else { return }
        inFlight.insert(id)

        guard WCSession.isSupported() else {
            inFlight.remove(id)
            return
        }
        let session = WCSession.default
        guard session.isReachable else {
            inFlight.remove(id)
            return
        }

        session.sendMessage(["type": "requestArtImage", "id": id, "imageName": imageName], replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(id)

                guard let b64 = reply["imageBase64"] as? String, !b64.isEmpty,
                      let data = Data(base64Encoded: b64),
                      let uiImage = UIImage(data: data)
                else { return }

                self.imagesByID[id] = uiImage
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.inFlight.remove(id)
                self?.lastError = error.localizedDescription
            }
        })
        #endif
    }

    func fetchFullIfNeeded(id: String, imageName: String) {
        #if canImport(UIKit)
        guard fullImagesByID[id] == nil else { return }
        let key = "full:" + id
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)

        guard WCSession.isSupported() else {
            inFlight.remove(key)
            return
        }
        let session = WCSession.default
        guard session.isReachable else {
            inFlight.remove(key)
            return
        }

        session.sendMessage(["type": "requestArtImageFull", "id": id, "imageName": imageName], replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(key)

                guard let b64 = reply["imageBase64"] as? String, !b64.isEmpty,
                      let data = Data(base64Encoded: b64),
                      let uiImage = UIImage(data: data)
                else { return }

                self.fullImagesByID[id] = uiImage
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.inFlight.remove(key)
                self?.lastError = error.localizedDescription
            }
        })
        #endif
    }
}


@MainActor
final class WatchMeowTalkSync: ObservableObject {
    static let shared = WatchMeowTalkSync()

    @Published var phrase: String = ""
    @Published var lastError: String? = nil
    @Published var isLoading: Bool = false

    private init() {
        activateIfPossible()
    }

    private func activateIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .notActivated {
            session.activate()
        }
    }

    func refresh() {
        activateIfPossible()
        lastError = nil
        isLoading = true

        guard WCSession.isSupported() else {
            isLoading = false
            lastError = "WatchConnectivity not supported"
            return
        }

        let session = WCSession.default
        guard session.isReachable else {
            isLoading = false
            lastError = "Open Meowbah on your iPhone to sync."
            return
        }

        session.sendMessage(["type": "requestMeowTalk"], replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                let p = (reply["phrase"] as? String) ?? ""
                self.phrase = p
                if p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.lastError = "No phrase available"
                }
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }
}

extension WatchVideoSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            Task { @MainActor in self.lastError = error.localizedDescription }
        }
    }

    // Required on watchOS
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        // Optional: auto-refresh when phone becomes reachable.
        if session.isReachable {
            Task { @MainActor in self.refresh() }
        }
    }
}


extension WatchMerchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            Task { @MainActor in self.lastError = error.localizedDescription }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Task { @MainActor in self.refresh() }
        }
    }
}

extension WatchArtSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            Task { @MainActor in self.lastError = error.localizedDescription }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Task { @MainActor in self.refresh() }
        }
    }
}


@MainActor
final class WatchMerchImageStore: ObservableObject {
    static let shared = WatchMerchImageStore()

    @Published private(set) var imagesByID: [String: UIImage] = [:]
    private var inFlight: Set<String> = []

    private init() {}

    func image(for id: String) -> UIImage? {
        imagesByID[id]
    }

    func fetchIfNeeded(id: String, imageName: String) {
        #if canImport(UIKit)
        guard imagesByID[id] == nil else { return }
        guard !inFlight.contains(id) else { return }
        inFlight.insert(id)

        guard WCSession.isSupported() else {
            inFlight.remove(id)
            return
        }
        let session = WCSession.default
        guard session.isReachable else {
            inFlight.remove(id)
            return
        }

        session.sendMessage(["type": "requestMerchImage", "id": id, "imageName": imageName], replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(id)

                guard let b64 = reply["imageBase64"] as? String, !b64.isEmpty,
                      let data = Data(base64Encoded: b64),
                      let uiImage = UIImage(data: data)
                else { return }

                self.imagesByID[id] = uiImage
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.inFlight.remove(id)
            }
        })
        #endif
    }
}

struct ContentView: View {
    @State private var selected: Item? = .videos

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                ForEach(Item.allCases, id: \.self) { item in
                    NavigationLink(item.title, value: item)
                        .labelStyle(.titleOnly)
                }
            }
            .containerBackground(meowPinkBackground, for: .navigation)
            .listStyle(.carousel)
        } detail: {
            DetailView(selected: $selected)
        }
    }
}

private struct DetailView: View {
    @Binding var selected: Item?

    var body: some View {
        Group {
            switch selected {
            case .videos:
                VideosPage()
            case .merch:
                MerchPage()
            case .art:
                ArtPage()
            case .meowTalk:
                MeowTalkPage()
            case .none:
                EmptyStatePage()
            }
        }
    }
}

private struct VideosPage: View {
    @StateObject private var sync = WatchVideoSync.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sync.isLoading {
                        HStack {
                            ProgressView()
                            Text("Syncing…")
                        }
                    } else if let err = sync.lastError, sync.videos.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        ForEach(sync.videos) { video in
                            NavigationLink(value: video) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.title)
                                        .lineLimit(2)

                                    if let date = video.publishedAt {
                                        Text(date, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Videos", systemImage: "play.rectangle.fill")
                }

                Section {
                    Button {
                        sync.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    if let err = sync.lastError, !err.isEmpty, !sync.videos.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationDestination(for: WatchVideoItem.self) { video in
                VideoDetailPage(video: video)
            }
        }
        .containerBackground(meowPinkBackground, for: .navigation)
        .onAppear {
            if sync.videos.isEmpty {
                sync.refresh()
            }
        }
    }
}

private struct MerchPage: View {
    @StateObject private var sync = WatchMerchSync.shared
    @StateObject private var images = WatchMerchImageStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sync.isLoading {
                        HStack {
                            ProgressView()
                            Text("Syncing…")
                        }
                    } else if let err = sync.lastError, sync.items.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        ForEach(sync.items) { item in
                            NavigationLink(value: item) {
                                HStack(spacing: 10) {
                                    if let uiImage = images.image(for: item.id) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.secondary.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                            .overlay { ProgressView() }
                                            .onAppear {
                                                images.fetchIfNeeded(id: item.id, imageName: item.imageName)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title.isEmpty ? "Merch Item" : item.title)
                                            .lineLimit(2)
                                        if !item.price.isEmpty {
                                            Text(item.price)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Merch", systemImage: "bag.fill")
                }

                Section {
                    Button {
                        sync.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    if let err = sync.lastError, !err.isEmpty, !sync.items.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationDestination(for: WatchMerchItem.self) { item in
                MerchDetailPage(item: item)
            }
        }
        .containerBackground(meowPinkBackground, for: .navigation)
        .onAppear {
            if sync.items.isEmpty {
                sync.refresh()
            }
        }
    }
}

private struct ArtPage: View {
    @StateObject private var sync = WatchArtSync.shared
    @StateObject private var images = WatchArtImageStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sync.isLoading {
                        HStack {
                            ProgressView()
                            Text("Syncing…")
                        }
                    } else if let err = sync.lastError, sync.items.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        ForEach(sync.items) { item in
                            NavigationLink(value: item) {
                                HStack(spacing: 10) {
                                    if let uiImage = images.image(for: item.id) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.secondary.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                            .overlay { ProgressView() }
                                            .onAppear {
                                                images.fetchIfNeeded(id: item.id, imageName: item.imageName)
                                            }
                                    }
                                    Text(item.title)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Art", systemImage: "paintpalette.fill")
                }

                Section {
                    Button {
                        sync.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    if let err = sync.lastError, !err.isEmpty, !sync.items.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationDestination(for: WatchArtItem.self) { item in
                ArtDetailPage(item: item)
            }
        }
        .containerBackground(meowPinkBackground, for: .navigation)
        .onAppear {
            if sync.items.isEmpty {
                sync.refresh()
            }
        }
    }
}


private struct MeowTalkPage: View {
    @StateObject private var sync = WatchMeowTalkSync.shared

    var body: some View {
        ZStack {
            // Pink tint background.
            LinearGradient(colors: [meowPinkTop, meowPinkBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            let phrase = sync.phrase.trimmingCharacters(in: .whitespacesAndNewlines)

            Text(phrase.isEmpty ? "…" : phrase)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(nil)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        // Tap anywhere to refresh.
        .contentShape(Rectangle())
        .onTapGesture {
            sync.refresh()
        }
        .onAppear {
            sync.refresh()
        }
    }
}


private struct EmptyStatePage: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Select a section")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}





private struct ShareBottomBar: View {
    let urlString: String
    let fallbackText: String

    var body: some View {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFallback = fallbackText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmedURL), !trimmedURL.isEmpty {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            // If we don't have a valid URL (common for Art), still show a native share button.
            ShareLink(item: trimmedFallback.isEmpty ? "Meowbah" : trimmedFallback) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

private struct VideoDetailPage: View {
    let video: WatchVideoItem
    @StateObject private var sync = WatchVideoSync.shared

    var body: some View {
        List {
            Section {
                if !video.thumbnailURLString.isEmpty, let thumbURL = URL(string: video.thumbnailURLString) {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.12))
                                ProgressView()
                            }
                            .frame(height: 90)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        case .failure:
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 90)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }

                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                Text(video.title)
                    .font(.headline)
                    .lineLimit(3)

                if let date = video.publishedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let trimmed = video.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Text(trimmed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .containerBackground(meowPinkBackground, for: .navigation)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    ShareBottomBar(urlString: video.urlString, fallbackText: video.title)
                    Spacer()
                }
            }
        }
    }
}

private struct MerchDetailPage: View {
    let item: WatchMerchItem
    @StateObject private var sync = WatchMerchSync.shared
    @StateObject private var images = WatchMerchImageStore.shared

    var body: some View {
        List {
            Section {
                if let uiImage = images.image(for: item.id) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .padding(.vertical, 2)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                        ProgressView()
                    }
                    .frame(height: 120)
                    .onAppear {
                        images.fetchIfNeeded(id: item.id, imageName: item.imageName)
                    }
                }

                Text(item.title.isEmpty ? "Merch" : item.title)
                    .font(.headline)
                    .lineLimit(3)

                if !item.price.isEmpty {
                    Text(item.price)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                let trimmed = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Text(trimmed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Details available on iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(meowPinkBackground, for: .navigation)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    ShareBottomBar(urlString: item.urlString, fallbackText: item.title)
                    Spacer()
                }
            }
        }
    }
}



private struct ArtDetailPage: View {
    let item: WatchArtItem
    @StateObject private var sync = WatchArtSync.shared
    @StateObject private var images = WatchArtImageStore.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [meowPinkTop, meowPinkBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if let uiImage = images.fullImage(for: item.id) ?? images.image(for: item.id) {
                ScrollView {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                }
                .onAppear {
                    // Ensure we have a thumb quickly, then request full.
                    images.fetchIfNeeded(id: item.id, imageName: item.imageName)
                    images.fetchFullIfNeeded(id: item.id, imageName: item.imageName)
                }
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let err = images.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .onAppear {
                    images.fetchIfNeeded(id: item.id, imageName: item.imageName)
                    images.fetchFullIfNeeded(id: item.id, imageName: item.imageName)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    if let full = images.fullImage(for: item.id),
                       let jpeg = full.jpegData(compressionQuality: 0.92),
                       let fileURL = meowTempJPEGURL(id: item.id, data: jpeg) {
                        ShareLink(
                            item: fileURL,
                            preview: SharePreview(
                                item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meowbah Art" : item.title,
                                image: Image(uiImage: full)
                            )
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        // Full image not loaded yet; fall back to text.
                        ShareBottomBar(urlString: item.urlString, fallbackText: item.title)
                    }
                    Spacer()
                }
            }
        }
    }
}

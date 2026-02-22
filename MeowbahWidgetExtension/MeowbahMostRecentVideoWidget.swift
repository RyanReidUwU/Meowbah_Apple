import WidgetKit
import SwiftUI
import Foundation

struct VideoSnippet: Hashable {
    let title: String
    let url: URL?
    let thumbnailData: Data?
}

struct MostRecentVideoEntry: TimelineEntry {
    let date: Date
    let videos: [VideoSnippet]
}

struct MostRecentVideoProvider: TimelineProvider {
    typealias Entry = MostRecentVideoEntry
    
    private let appGroupSuiteName = "group.meowbah"
    
    func placeholder(in context: Context) -> MostRecentVideoEntry {
        return MostRecentVideoEntry(
            date: Date(),
            videos: [
                VideoSnippet(
                    title: "Sample Video Title 1",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 2",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 3",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 4",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                )
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MostRecentVideoEntry) -> Void) {
        if let entry = loadEntry() {
            print("[Widget] Snapshot loaded from app group: videos count=\(entry.videos.count), titles=\(entry.videos.map { $0.title })")
            completion(entry)
            return
        }
        let fallback = MostRecentVideoEntry(
            date: Date(),
            videos: [
                VideoSnippet(
                    title: "Sample Video Title 1",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 2",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 3",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 4",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                )
            ]
        )
        print("[Widget] Snapshot using fallback sample data")
        completion(fallback)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MostRecentVideoEntry>) -> Void) {
        let entry = loadEntry() ?? MostRecentVideoEntry(
            date: Date(),
            videos: [
                VideoSnippet(
                    title: "Sample Video Title 1",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 2",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 3",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                ),
                VideoSnippet(
                    title: "Sample Video Title 4",
                    url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                    thumbnailData: nil
                )
            ]
        )
        print("[Widget] Timeline entry prepared: videos count=\(entry.videos.count), titles=\(entry.videos.map { $0.title })")
        let nextUpdate = Date().addingTimeInterval(60 * 30)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry() -> MostRecentVideoEntry? {
        guard let userDefaults = UserDefaults(suiteName: appGroupSuiteName) else {
            return nil
        }
        
        // Helper to load a snippet by prefix keys
        func loadSnippet(prefix: String) -> VideoSnippet? {
            let titleValue = userDefaults.string(forKey: "\(prefix).title") ?? userDefaults.string(forKey: "\(prefix).name")
            let urlString = userDefaults.string(forKey: "\(prefix).url")
            let fileString = userDefaults.string(forKey: "\(prefix).thumbnailFile")

            // If nothing exists for this prefix, treat it as missing.
            if titleValue == nil && urlString == nil && fileString == nil {
                return nil
            }

            let title = (titleValue?.isEmpty == false) ? (titleValue ?? "") : "Untitled Video"
            let url = urlString.flatMap(URL.init)

            var localData: Data? = nil
            if let fileString, let fileURL = URL(string: fileString) {
                let exists = FileManager.default.fileExists(atPath: fileURL.path)
                print("[Widget] Local thumbnail URL for \(prefix):", fileString, "exists:", exists)
                if exists {
                    localData = try? Data(contentsOf: fileURL)
                    if localData == nil { print("[Widget] Failed to read local thumbnail data for \(prefix)") }
                }
            } else if let fileString {
                print("[Widget] Invalid local thumbnail URL string for \(prefix):", fileString)
            }

            return VideoSnippet(title: title, url: url, thumbnailData: localData)
        }
        
        var snippets: [VideoSnippet] = []

        // Required first snippet: try the named key first, then a numeric key fallback.
        if let firstSnippet = loadSnippet(prefix: "videos.mostRecent") ?? loadSnippet(prefix: "videos.0") {
            snippets.append(firstSnippet)
        } else {
            // No required first snippet, so no entry can be formed
            return nil
        }

        // Try to load up to 3 more snippets from both naming schemes.
        let candidatePrefixes = [
            "videos.second",
            "videos.third",
            "videos.fourth",
            "videos.1",
            "videos.2",
            "videos.3"
        ]

        for prefix in candidatePrefixes {
            guard snippets.count < 4 else { break }
            if let snippet = loadSnippet(prefix: prefix) {
                // Avoid duplicates if the app writes both schemes.
                if !snippets.contains(snippet) {
                    snippets.append(snippet)
                }
            }
        }
        
        print("[Widget] Loaded from app group: videos count=\(snippets.count), titles=\(snippets.map { $0.title })")
        
        return MostRecentVideoEntry(date: Date(), videos: snippets)
    }
}

struct MeowbahMostRecentVideoWidget: Widget {
    let kind: String = "MeowbahMostRecentVideoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MostRecentVideoProvider()) { entry in
            MostRecentVideoWidgetView(entry: entry)
        }
        .configurationDisplayName("Most Recent Video")
        .description("Displays the most recent video published.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

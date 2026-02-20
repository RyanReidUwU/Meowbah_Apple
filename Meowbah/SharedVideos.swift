import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - UI Video Model

public struct Video: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let thumbnailURL: URL?
    public let publishedAt: Date?
    public let channelTitle: String?
    public let durationSeconds: Int?

    public init(
        id: String,
        title: String,
        description: String,
        thumbnailURL: URL?,
        publishedAt: Date?,
        channelTitle: String?,
        durationSeconds: Int?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.channelTitle = channelTitle
        self.durationSeconds = durationSeconds
    }

    public var publishedAtFormatted: String {
        guard let publishedAt else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: publishedAt)
    }

    public var formattedDuration: String {
        guard let s = durationSeconds else { return "" }
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let seconds = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }
}

// MARK: - YouTube RSS Client (Fixed feed URL)

public actor YouTubeAPIClient {
    public static let shared = YouTubeAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Fetch videos directly from the fixed RSS feed:
    /// https://www.youtube.com/feeds/videos.xml?channel_id=UCNytjdD5-KZInxjVeWV_qQw
    public func fetchLatestVideos(maxResults: Int = 25) async throws -> [Video] {
        guard let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCNytjdD5-KZInxjVeWV_qQw") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        // Diagnostics: HTTP status and data size
        if let http = response as? HTTPURLResponse {
            if http.statusCode != 200 {
                print("YouTube RSS HTTP status:", http.statusCode)
            }
        }
        if data.isEmpty {
            print("YouTube RSS returned empty data")
        } else {
            print("YouTube RSS data size:", data.count, "bytes")
        }

        let parser = YouTubeRSSParser()
        let videos = try parser.parse(data: data)

        if maxResults > 0 {
            return Array(videos.prefix(maxResults))
        } else {
            return videos
        }
    }
}

private final class YouTubeRSSParser: NSObject, XMLParserDelegate {

    private var videos: [Video] = []
    private var insideEntry = false
    private var insideMediaGroup = false

    private var currentID: String?
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPublished: Date?
    private var currentThumbnail: URL?
    private var currentChannelTitle: String?
    private var currentDuration: Int?

    private var currentText = ""

    private func decodeHTMLEntities(_ input: String) -> String {
        // Iteratively decode until no changes occur, up to 3 passes to avoid runaway loops.
        var previous = input
        for _ in 0..<3 {
            var s = previous

            // Named entities (do these first so &amp;#x... becomes &#x... on next pass)
            let named: [String: String] = [
                "&amp;": "&",
                "&lt;": "<",
                "&gt;": ">",
                "&quot;": "\"",
                "&apos;": "'"
            ]
            for (entity, char) in named {
                s = s.replacingOccurrences(of: entity, with: char)
            }

            // Numeric hex entities with optional semicolon: &#xHHHH; or &#xHHHH
            if let regex = try? NSRegularExpression(pattern: "&#x([0-9A-Fa-f]+);?", options: []) {
                let matches = regex.matches(in: s, options: [], range: NSRange(s.startIndex..., in: s))
                var mutable = s
                for match in matches.reversed() {
                    if match.numberOfRanges == 2,
                       let range = Range(match.range(at: 1), in: s),
                       let codePoint = UInt32(s[range], radix: 16),
                       let scalar = UnicodeScalar(codePoint) {
                        let replacement = String(scalar)
                        if let fullRange = Range(match.range(at: 0), in: s) {
                            mutable.replaceSubrange(fullRange, with: replacement)
                        }
                    }
                }
                s = mutable
            }

            // Numeric decimal entities with optional semicolon: &#DDDD; or &#DDDD
            if let regex = try? NSRegularExpression(pattern: "&#(\\d+);?", options: []) {
                let matches = regex.matches(in: s, options: [], range: NSRange(s.startIndex..., in: s))
                var mutable = s
                for match in matches.reversed() {
                    if match.numberOfRanges == 2,
                       let range = Range(match.range(at: 1), in: s),
                       let codePoint = Int(s[range]),
                       let scalar = UnicodeScalar(codePoint) {
                        let replacement = String(scalar)
                        if let fullRange = Range(match.range(at: 0), in: s) {
                            mutable.replaceSubrange(fullRange, with: replacement)
                        }
                    }
                }
                s = mutable
            }

            if s == previous { return s }
            previous = s
        }
        return previous
    }

    func parse(data: Data) throws -> [Video] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()
        if !success {
            let err = parser.parserError ?? URLError(.cannotParseResponse)
            print("XMLParser failed:", err.localizedDescription)
            throw err
        }
        print("Parsed entries:", videos.count)
        return videos.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {

        currentText = ""

        if elementName == "entry" {
            insideEntry = true
            insideMediaGroup = false
            currentID = nil
            currentTitle = ""
            currentDescription = ""
            currentPublished = nil
            currentThumbnail = nil
            currentChannelTitle = nil
            currentDuration = nil
        }

        if insideEntry {
            if elementName == "media:group" {
                insideMediaGroup = true
            }

            // Prefer the highest resolution thumbnail encountered
            if elementName == "media:thumbnail",
               let urlString = attributeDict["url"] {
                currentThumbnail = URL(string: urlString)
            }

            // Duration (seconds attribute)
            if insideMediaGroup,
               elementName == "yt:duration",
               let secondsString = attributeDict["seconds"],
               let seconds = Int(secondsString) {
                currentDuration = seconds
            }

            // Fallback: some feeds provide duration on media:content as an attribute
            if insideMediaGroup,
               elementName == "media:content",
               let durString = attributeDict["duration"],
               let seconds = Int(durString) {
                currentDuration = seconds
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {

        guard insideEntry else { return }

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {

        case "yt:videoId":
            currentID = trimmed

        case "title":
            currentTitle = decodeHTMLEntities(trimmed)

        case "media:title":
            if currentTitle.isEmpty {
                currentTitle = decodeHTMLEntities(trimmed)
            }

        case "media:description":
            print("RAW DESC:", trimmed)
            let decoded = decodeHTMLEntities(trimmed)
            print("DECODED DESC:", decoded)
            currentDescription = decoded

        case "published":
            currentPublished = ISO8601DateFormatter().date(from: trimmed)

        case "name":
            currentChannelTitle = trimmed

        case "media:group":
            insideMediaGroup = false

        case "entry":
            if let id = currentID {
                let video = Video(
                    id: id,
                    title: currentTitle,
                    description: currentDescription,
                    thumbnailURL: currentThumbnail,
                    publishedAt: currentPublished,
                    channelTitle: currentChannelTitle,
                    durationSeconds: currentDuration
                )
                videos.append(video)
                print("Parsed video:", id, "-", currentTitle)
            } else {
                print("Skipping entry without yt:videoId. Title:", currentTitle)
            }
            insideEntry = false
            insideMediaGroup = false

        default:
            break
        }
    }
}

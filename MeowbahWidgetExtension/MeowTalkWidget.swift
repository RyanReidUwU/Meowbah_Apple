// MeowTalkWidget.swift
// MeowbahWidgetExtension

import WidgetKit
import SwiftUI
import os

struct MeowTalkEntry: TimelineEntry {
    let date: Date
    let phrase: String
}

struct MeowTalkProvider: TimelineProvider {
    typealias Entry = MeowTalkEntry
    private let appGroupSuiteName = "group.meowbah"
    private let phraseKey = "meowtalk.current.phrase"
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MeowbahWidgetExtension", category: "MeowTalkWidget")
    private func dbg(_ message: String) {
        // `print` shows up in Xcode debug console when running the widget extension.
        // `NSLog` is more likely to appear in Console.app/device logs.
        print("[MeowTalkWidget] \(message)")
        NSLog("[MeowTalkWidget] \(message)")
    }

    func placeholder(in context: Context) -> MeowTalkEntry {
        dbg("placeholder called")
        return MeowTalkEntry(date: Date(), phrase: "Nyaa~ Hello!")
    }

    func getSnapshot(in context: Context, completion: @escaping (MeowTalkEntry) -> Void) {
        dbg("getSnapshot called; isPreview=\(context.isPreview)")
        let entry = loadEntry() ?? MeowTalkEntry(date: Date(), phrase: "Nyaa~ Hello!")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeowTalkEntry>) -> Void) {
        dbg("getTimeline called")
        let entry = loadEntry() ?? MeowTalkEntry(date: Date(), phrase: "Nyaa~ Hello!")
        let next = Date().addingTimeInterval(60 * 30)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> MeowTalkEntry? {
        dbg("loadEntry starting (suite=\(appGroupSuiteName), key=\(phraseKey))")
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else {
            log.error("Failed to create UserDefaults for suite: \(self.appGroupSuiteName, privacy: .public)")
            dbg("UserDefaults(suiteName:) returned nil — App Group likely missing/mismatched for the widget extension")
            return nil
        }

        let phrase = defaults.string(forKey: phraseKey)
        if let raw = defaults.object(forKey: phraseKey) {
            dbg("raw value for key is type=\(type(of: raw))")
        } else {
            dbg("no value stored for key")
        }
        if let phrase, !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dbg("returning phrase: \(phrase)")
            log.debug("Loaded phrase: \(phrase, privacy: .public)")
            return MeowTalkEntry(date: Date(), phrase: phrase)
        }

        // Helpful diagnostics: if the key exists but isn't a String, or it's empty.
        if defaults.object(forKey: phraseKey) != nil {
            log.debug("Phrase key exists but value is empty or not a String.")
            dbg("key exists but phrase string is empty/whitespace or not a String")
        } else {
            log.debug("No phrase saved yet for key: \(self.phraseKey, privacy: .public)")
            dbg("key missing")
        }

        return nil
    }
}

struct MeowTalkWidgetView: View {
    var entry: MeowTalkProvider.Entry

    var body: some View {
        ZStack {
            Text(entry.phrase)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct MeowTalkWidget: Widget {
    let kind: String = "MeowTalkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeowTalkProvider()) { entry in
            MeowTalkWidgetView(entry: entry)
        }
        .configurationDisplayName("MeowTalk")
        .description("Shows the current MeowTalk phrase.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

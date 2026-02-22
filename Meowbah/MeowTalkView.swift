import SwiftUI
import WidgetKit
#if canImport(UserNotifications)
import UserNotifications
#endif


struct MeowTalkView: View {
    private static let appGroupID = "group.meowbah"
    private static let appGroupDefaults = UserDefaults(suiteName: appGroupID)!
    private static let currentPhraseKey = "meowtalk.current.phrase"

    private struct RefreshIntervalOption: Identifiable, Hashable {
        let title: String
        let seconds: TimeInterval

        var id: TimeInterval { seconds }

        static let every15m = RefreshIntervalOption(title: "Every 15 Minutes", seconds: 15 * 60)
        static let every30m = RefreshIntervalOption(title: "Every 30 Minutes", seconds: 30 * 60)
        static let every1h  = RefreshIntervalOption(title: "Every 1 Hour", seconds: 60 * 60)
        static let every2h  = RefreshIntervalOption(title: "Every 2 Hours", seconds: 2 * 60 * 60)
        static let every4h  = RefreshIntervalOption(title: "Every 4 Hours", seconds: 4 * 60 * 60)
        static let every8h  = RefreshIntervalOption(title: "Every 8 Hours", seconds: 8 * 60 * 60)

        static let all: [RefreshIntervalOption] = [
            .every15m, .every30m, .every1h, .every2h, .every4h, .every8h
        ]
    }

    @AppStorage("meowtalk.refreshSeconds", store: Self.appGroupDefaults) private var storedRefreshSeconds: Double = 60 * 60
    @AppStorage("meowtalk.didRequestNotificationPermission", store: Self.appGroupDefaults) private var didRequestNotificationPermission: Bool = false
    @AppStorage("meowtalk.seed", store: Self.appGroupDefaults) private var storedSeed: String = ""
    @AppStorage("meowtalk.anchorTimestamp", store: Self.appGroupDefaults) private var anchorTimestamp: Double = 0
    @State private var refreshOption: RefreshIntervalOption = .every1h
    @State private var refreshTask: Task<Void, Never>?
    @State private var message: String = ""
    @Environment(\.scenePhase) private var scenePhase

    private let phrases: [String] = [
        "Purr... Feeling cute today!",
        "Time for a digital head boop!",
        "Meow! Hope you're having a pawsome day!",
        "Did you know cats spend 70% of their lives sleeping? Goals!",
        "Just saw a virtual bird, it was riveting.",
        "Remember to stretch and land on your feet!",
        "Sending purrs and good vibes your way!",
        "Is it snack o'clock yet? Always is in my world.",
        "The keyboard is surprisingly comfy.",
        "Stay curious and keep exploring!",
        "If I fits, I sits... even in the digital realm.",
        "Chasing the red dot of destiny today.",
        "May your day be filled with sunbeams and gentle breezes.",
        "Let's make some mischief! Or maybe just nap.",
        "My meowtivation level is... surprisingly high right now!",
        "Just a little reminder that you're purrfect.",
        "Current mood: Zoomies, followed by a long nap.",
        "The internet is my giant litter box of information!",
        "Do you ever just stare blankly at a wall? It's an art form.",
        "Thinking about important cat stuff. You wouldn't understand.",
        "Meow does not have a race, Meow is a doll, dolls don't have races, silly.",
        "Jellybean-Sama!",
        "Arigato for educating Meow. Gomenasai, friends...Meow promises never to say that word again...",
        "Woof...hee-hee...bark, bark...",
        "Kawaii and small...uwu",
        "Meow is having a great day!",
        "Reading meow's discord questions!",
        "Meows gonna do unspeakable things to ur plush dada @zaptiee ( ´ ∀ `)ノ～ ♡",
        "KYAAAAA~~",
        "Rice Krispies are Meow's all-time favourite food!!",
        "nyahallo!!",
        "Meows selling a bodypillow!",
        "NYAN NYAN NIHAO NYAN!!"
    ]

    @State private var selectedPhrase: String = ""

    private func ensureSeedAndAnchor() {
        if storedSeed.isEmpty {
            storedSeed = String(UInt64.random(in: UInt64.min...UInt64.max))
        }
        if anchorTimestamp == 0 {
            // Anchor to “now” so slot 0 starts immediately.
            anchorTimestamp = Date().timeIntervalSince1970
        }
    }

    private func currentSlotIndex(now: Date = Date()) -> Int {
        let interval = max(1, refreshOption.seconds)
        let delta = now.timeIntervalSince1970 - anchorTimestamp
        if delta <= 0 { return 0 }
        return Int(floor(delta / interval))
    }

    private func phrase(forSlot slot: Int) -> String {
        guard !phrases.isEmpty else { return "Meow" }

        let seed = UInt64(storedSeed) ?? 0
        // A tiny deterministic hash (splitmix64-ish) so each slot maps to a stable index.
        var x = seed &+ UInt64(slot) &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)

        let idx = Int(x % UInt64(phrases.count))
        return phrases[idx]
    }

    private func updateDisplayedPhrase(now: Date = Date()) {
        ensureSeedAndAnchor()
        let slot = currentSlotIndex(now: now)
        let next = phrase(forSlot: slot)
        selectedPhrase = next

        // Share the on-screen phrase with the widget/watch via the App Group.
        Self.appGroupDefaults.set(next, forKey: Self.currentPhraseKey)

        // Keep any existing shared-state mechanism (if used elsewhere).
        MeowTalkSharedState.setCurrentPhrase(next)

        // Prompt the widget to refresh promptly.
        WidgetCenter.shared.reloadTimelines(ofKind: "MeowTalkWidget")

        let readBack = Self.appGroupDefaults.string(forKey: Self.currentPhraseKey) ?? "nil"
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?.absoluteString ?? "nil"
        print("[MeowTalkApp] Saved phrase to app group: \(next)")
        print("[MeowTalkApp] Read-back phrase: \(readBack)")
        print("[MeowTalkApp] App Group container: \(containerURL)")
    }

    private func secondsUntilNextSlot(now: Date = Date()) -> TimeInterval {
        let interval = max(1, refreshOption.seconds)
        let slot = currentSlotIndex(now: now)
        let nextBoundary = anchorTimestamp + (TimeInterval(slot + 1) * interval)
        return max(0.5, nextBoundary - now.timeIntervalSince1970)
    }

    private func sendNotification(for phrase: String, trigger: UNNotificationTrigger) {
#if canImport(UserNotifications)
#if !os(tvOS)
        let content = UNMutableNotificationContent()
        content.title = "MeowTalk"
        content.body = phrase
        content.sound = .default
        #if os(visionOS)
        if #available(visionOS 1.0, *) {
            content.interruptionLevel = .active
            content.relevanceScore = 0.6
        }
        #endif

        let request = UNNotificationRequest(
            identifier: "meowtalk.phrase.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
#endif
#endif
    }

    @MainActor
    private func requestNotificationPermissionIfNeeded() async {
        #if canImport(UserNotifications)
        #if !os(tvOS)
        // Only prompt while the app is active; otherwise the system prompt may not appear.
        guard scenePhase == .active else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }

        didRequestNotificationPermission = true
        #endif
        #endif
    }

    private func scheduleUpcomingPhraseNotifications() {
        #if canImport(UserNotifications)
        #if !os(tvOS)
        // Schedule notifications ahead of time because backgrounded apps don’t run the refresh timer.
        let center = UNUserNotificationCenter.current()

        // Schedule up to the next 24 hours, capped to a reasonable count.
        let horizon: TimeInterval = 24 * 60 * 60
        let count = max(1, min(64, Int(horizon / max(1, refreshOption.seconds))))

        let ids = (0..<count).map { "meowtalk.scheduled.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        ensureSeedAndAnchor()
        let now = Date()
        let currentSlot = currentSlotIndex(now: now)
        let interval = max(1, refreshOption.seconds)

        for i in 0..<count {
            let slot = currentSlot + i + 1
            let phrase = phrase(forSlot: slot)

            // Fire at the next slot boundary + i slots.
            let fireAt = anchorTimestamp + (TimeInterval(slot) * interval)
            let delay = max(1, fireAt - now.timeIntervalSince1970)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = "MeowTalk"
            content.body = phrase
            content.sound = .default
            #if os(visionOS)
            if #available(visionOS 1.0, *) {
                content.interruptionLevel = .active
                content.relevanceScore = 0.6
            }
            #endif

            let req = UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger)
            center.add(req)
        }
        #endif
        #endif
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            // Small delay so the menu can dismiss cleanly.
            try? await Task.sleep(nanoseconds: 150_000_000)

            while !Task.isCancelled {
                await MainActor.run {
                    updateDisplayedPhrase()
                }

                let wait = secondsUntilNextSlot()
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    var body: some View {
        ZStack {
#if os(tvOS)
            Color.black
                .ignoresSafeArea()
#else
            Color(.systemBackground)
                .ignoresSafeArea()
#endif

            VStack {
                Spacer()

                Text(selectedPhrase)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary)
                    .padding(24)

                Spacer()
            }
        }
        .onAppear {
            // Restore saved refresh interval (defaults to 1 hour).
            if let restored = RefreshIntervalOption.all.first(where: { Double($0.seconds) == storedRefreshSeconds }) {
                refreshOption = restored
            } else {
                refreshOption = .every1h
                storedRefreshSeconds = Double(refreshOption.seconds)
            }

            ensureSeedAndAnchor()
            updateDisplayedPhrase()

            Task { @MainActor in
                // Give SwiftUI a moment to finish presenting the view before showing the system prompt.
                try? await Task.sleep(nanoseconds: 400_000_000)
                await requestNotificationPermissionIfNeeded()
                scheduleUpcomingPhraseNotifications()
            }

            startAutoRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onChange(of: refreshOption) { _ in
            anchorTimestamp = Date().timeIntervalSince1970
            startAutoRefresh()
            scheduleUpcomingPhraseNotifications()
        }
        .navigationTitle("MeowTalk")
#if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        Task { @MainActor in
                            await requestNotificationPermissionIfNeeded()
                        }
                    } label: {
                        Label("Enable Notifications", systemImage: "bell")
                    }

                    Divider()

                    ForEach(RefreshIntervalOption.all) { opt in
                        Button {
                            refreshOption = opt
                            storedRefreshSeconds = Double(opt.seconds)
                            anchorTimestamp = Date().timeIntervalSince1970
                            updateDisplayedPhrase()
                            scheduleUpcomingPhraseNotifications()
                        } label: {
                            if opt == refreshOption {
                                Label(opt.title, systemImage: "checkmark")
                            } else {
                                Text(opt.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "clock")
                }
                .accessibilityLabel("Clock")
            }
        }
#endif
    }
}

#Preview {
    NavigationStack {
        MeowTalkView()
    }
}

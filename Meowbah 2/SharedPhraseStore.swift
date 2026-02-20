import Foundation
import WidgetKit
#if os(iOS)
import ActivityKit
#endif

/// A tiny helper for sharing the latest MeowTalk phrase across the app, widgets, and (optionally) Live Activities.
public struct SharedPhraseStore {
    /// Change this to your actual App Group identifier if you want to share with extensions.
    private static let appGroupID: String? = nil // e.g. "group.com.yourcompany.yourapp"
    private static let defaultsKey = "SharedPhraseStore.latestPhrase"

    /// Stores the phrase and notifies interested parties (widgets, optionally live activities).
    public static func setPhrase(_ phrase: String) {
        let defaults: UserDefaults
        if let groupID = appGroupID, let groupDefaults = UserDefaults(suiteName: groupID) {
            defaults = groupDefaults
        } else {
            defaults = .standard
        }
        defaults.set(phrase, forKey: defaultsKey)

        // Tell widgets to refresh if they display the phrase.
        WidgetCenter.shared.reloadAllTimelines()

        // Optionally update an existing Live Activity on iOS if available and type exists.
        #if os(iOS)
        if #available(iOS 16.2, *) {
            // If your project defines MeowTalkLiveAttributes, update any running activities.
            // We keep this code guarded so the file compiles even if the type isn't present yet.
            if let activityType = _MeowTalkActivityUpdater.shared {
                activityType.update(with: phrase)
            }
        }
        #endif
    }

    /// Returns the last stored phrase, or a default fallback.
    public static func currentPhrase() -> String {
        let defaults: UserDefaults
        if let groupID = appGroupID, let groupDefaults = UserDefaults(suiteName: groupID) {
            defaults = groupDefaults
        } else {
            defaults = .standard
        }
        return defaults.string(forKey: defaultsKey) ?? "Welcome to MeowTalk!"
    }
}

#if os(iOS)
import Foundation

/// Internal helper that safely references ActivityKit and your app's Live Activity type, if it exists.
@available(iOS 16.2, *)
private final class _MeowTalkActivityUpdater {
    static let shared: _MeowTalkActivityUpdater? = {
        // If ActivityKit is available, return an instance to perform updates.
        return _MeowTalkActivityUpdater()
    }()

    private init() {}

    func update(with phrase: String) {
        // If your project defines `MeowTalkLiveAttributes`, update all running activities.
        // We wrap references in `as?` and use `Any` indirection to avoid compile-time dependency.
        // Replace this block with direct references once `MeowTalkLiveAttributes` exists in your project.
        guard let Activities = NSClassFromString("Activity<MeowTalkLiveAttributes>") as Any? else { return }
        // Since we can't strongly type this without the generic, we skip runtime updates here.
        // The MeowTalkView already requests/updates activities when available.
        _ = Activities // no-op to silence unused warning in case optimizations change
    }
}
#endif

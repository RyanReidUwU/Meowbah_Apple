import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

@available(iOS 16.1, *)
public struct MeowTalkLiveAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // The current phrase to show in the Live Activity / Dynamic Island
        public var phrase: String

        public init(phrase: String) {
            self.phrase = phrase
        }
    }

    // A simple attribute for demonstration; not used for rendering but part of the attributes
    public var name: String

    public init(name: String) {
        self.name = name
    }
}
#else
// Fallback stub for platforms without ActivityKit (e.g., Mac Catalyst)
public struct MeowTalkLiveAttributes {
    public struct ContentState: Codable, Hashable {
        public var phrase: String
        public init(phrase: String) { self.phrase = phrase }
    }
    public var name: String
    public init(name: String) { self.name = name }
}
#endif



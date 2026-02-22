//
//  WidgetHelper.swift
//  Meowbah
//
//  Created by Ryan Reid on 21/02/2026.
//

import Foundation

enum MeowTalkShared {
    static let refreshSecondsKey = "meowtalk.refreshSeconds"
    static let seedKey = "meowtalk.seed"
    static let anchorKey = "meowtalk.anchorTimestamp"

    static func ensureSeedAndAnchor(defaults: UserDefaults) {
        if (defaults.string(forKey: seedKey) ?? "").isEmpty {
            defaults.set(String(UInt64.random(in: UInt64.min...UInt64.max)), forKey: seedKey)
        }
        if defaults.double(forKey: anchorKey) == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: anchorKey)
        }
    }

    static func currentSlotIndex(now: Date, interval: TimeInterval, anchor: TimeInterval) -> Int {
        let interval = max(1, interval)
        let delta = now.timeIntervalSince1970 - anchor
        if delta <= 0 { return 0 }
        return Int(floor(delta / interval))
    }

    static func phrase(forSlot slot: Int, seedString: String, phrases: [String]) -> String {
        guard !phrases.isEmpty else { return "Meow" }

        let seed = UInt64(seedString) ?? 0
        var x = seed &+ UInt64(slot) &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)

        let idx = Int(x % UInt64(phrases.count))
        return phrases[idx]
    }

    static func nextBoundaryDate(now: Date, interval: TimeInterval, anchor: TimeInterval) -> Date {
        let slot = currentSlotIndex(now: now, interval: interval, anchor: anchor)
        let nextBoundary = anchor + (TimeInterval(slot + 1) * max(1, interval))
        return Date(timeIntervalSince1970: nextBoundary)
    }
}

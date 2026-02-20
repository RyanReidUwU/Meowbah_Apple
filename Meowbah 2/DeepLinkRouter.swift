// DeepLinkRouter.swift
// Meowbah
//
// Handles tab selection and routing for deep links.
//

import SwiftUI
import Combine

// The set of tabs your app supports. Should match ContentView's TabTag enum cases and any router logic.
public enum AppTab: Hashable, Equatable, Codable {
    case videos
    case profile
    case other // fallback or placeholder for unknown cases
}

// ObservableObject router to sync deep-link tab selection with ContentView.
final class DeepLinkRouter: ObservableObject {
    @Published var selectedTab: AppTab = .videos
    
    // Example: support for parsing incoming URLs (add as needed)
    func handle(url: URL) {
        // Simple example: route to a tab based on URL path
        if url.path.contains("profile") {
            selectedTab = .profile
        } else if url.path.contains("videos") {
            selectedTab = .videos
        } else {
            selectedTab = .other
        }
    }
}


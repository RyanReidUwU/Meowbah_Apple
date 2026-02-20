//
//  BackgroundRefreshManager.swift
//  Meowbah
//
//  Periodically fetches the YouTube RSS feed in the background and posts local notifications for new videos.
//

#if os(iOS) || os(tvOS) || os(visionOS)

import Foundation
import BackgroundTasks
import UserNotifications
import SwiftUI
import Combine

enum BackgroundRefreshConfig {
    // The task identifier must also appear in Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let refreshTaskIdentifier = "com.meowbah.refresh"

    // How often we ask iOS to wake us. iOS may coalesce/schedule differently.
    static let minimumRefreshInterval: TimeInterval = 30 * 60 // 30 minutes
}

// A simple store for seen video IDs to detect new items.
private enum SeenVideosStore {
    private static let key = "SeenVideoIDs"

    static func load() -> Set<String> {
        let arr = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        return Set(arr)
    }

    static func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}

@MainActor
final class BackgroundRefreshManager: ObservableObject {
    static let shared = BackgroundRefreshManager()

    private init() { }

    // Call from app launch
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundRefreshConfig.refreshTaskIdentifier, using: nil) { task in
            // Handle background refresh task
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    // Call when entering background (or at suitable times) to schedule the next refresh
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundRefreshConfig.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: BackgroundRefreshConfig.minimumRefreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
            // print("[BGTask] Scheduled next refresh")
        } catch {
            // print("[BGTask] Failed to schedule: \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately so we keep getting opportunities
        scheduleNextRefresh()

        // Create an operation that runs the RSS fetch and notification logic.
        let operation = BackgroundFetchOperation()

        // Expiration handler: cancel work if iOS asks us to stop.
        task.expirationHandler = {
            operation.cancel()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Kick off on a background queue
        OperationQueue().addOperation(operation)
    }
}

// MARK: - BackgroundFetchOperation

private final class BackgroundFetchOperation: Operation {
    private var isOpFinished = false
    private var isOpExecuting = false

    override var isAsynchronous: Bool { true }
    override private(set) var isFinished: Bool {
        get { isOpFinished }
        set {
            willChangeValue(forKey: "isFinished")
            isOpFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    override private(set) var isExecuting: Bool {
        get { isOpExecuting }
        set {
            willChangeValue(forKey: "isExecuting")
            isOpExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }
        isExecuting = true

        Task {
            await run()
            finish()
        }
    }

    private func finish() {
        isExecuting = false
        isFinished = true
    }

    private func run() async {
        // Currently not using any API; no background work to perform.
        // Still check notification permissions to mirror original intent.
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        // No-op: nothing to fetch or notify about.
    }
}

#else

// Fallback stub so the symbol exists when BackgroundTasks is unavailable (e.g., previews/tests/other targets).
import Foundation
import SwiftUI
import Combine

@MainActor
final class BackgroundRefreshManager: ObservableObject {
    static let shared = BackgroundRefreshManager()
    private init() { }

    func register() { /* no-op */ }
    func scheduleNextRefresh() { /* no-op */ }
}

#endif

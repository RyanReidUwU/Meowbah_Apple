import Foundation
import SwiftUI
import Combine

#if canImport(BackgroundTasks) && (os(iOS) || os(visionOS))
import BackgroundTasks

enum MeowTalkBackgroundConfig {
    static let taskIdentifier = "com.meowbah.meowtalk.refresh"
}

@MainActor
final class MeowTalkBackgroundManager: ObservableObject {
    static let shared = MeowTalkBackgroundManager()
    private init() { }

    // Register the background task handler
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: MeowTalkBackgroundConfig.taskIdentifier, using: nil) { task in
            self.handle(task: task as! BGAppRefreshTask)
        }
    }

    // Schedule next run based on user interval (seconds)
    func scheduleNextRun() {
        let intervalSeconds = max(1, UserDefaults.standard.double(forKey: "meowTalkIntervalSeconds"))
        let request = BGAppRefreshTaskRequest(identifier: MeowTalkBackgroundConfig.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: intervalSeconds)
        do { try BGTaskScheduler.shared.submit(request) } catch { }
    }

    private func handle(task: BGAppRefreshTask) {
        scheduleNextRun() // ensure future runs

        let operation = PhraseNotifyOperation()
        task.expirationHandler = {
            operation.cancel()
        }
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        OperationQueue().addOperation(operation)
    }
}

private final class PhraseNotifyOperation: Operation {
    private var _executing = false
    private var _finished = false

    override var isAsynchronous: Bool { true }
    override private(set) var isExecuting: Bool {
        get { _executing }
        set {
            willChangeValue(forKey: "isExecuting"); _executing = newValue; didChangeValue(forKey: "isExecuting")
        }
    }
    override private(set) var isFinished: Bool {
        get { _finished }
        set {
            willChangeValue(forKey: "isFinished"); _finished = newValue; didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        if isCancelled { finish(); return }
        isExecuting = true
        Task { await run(); finish() }
    }

    private func finish() { isExecuting = false; isFinished = true }

    private func run() async {
        // Respect notification permissions and user preference (handled in helper)
        // Pick a random phrase (mirror the ones in MeowTalkView)
        let phrases = [
            "Welcome to MeowTalk!",
            "Say hi to your fellow cats 🐾",
            "Nyaa~ How are you today?",
            "Purr... this app is so comfy!",
            "Treats time? 🍣"
        ]
        guard let phrase = phrases.randomElement() else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "MeowTalk"
        content.body = phrase
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}

#else

@MainActor
final class MeowTalkBackgroundManager: ObservableObject {
    static let shared = MeowTalkBackgroundManager()
    private init() { }
    func register() { }
    func scheduleNextRun() { }
}

#endif

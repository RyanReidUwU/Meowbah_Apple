//
//  NotificationHelper.swift
//  Meowbah
//
//  Shared local notification helper usable from foreground and background.
//

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum NotificationHelper {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func scheduleNewVideoNotification(video: Video) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Nyaa~ New video just dropped!"
        content.body = video.title.isEmpty ? "Tap to watch meow!" : "“\(video.title)” is ready to watch. Tap to play!"
        content.sound = .default
        content.badge = NSNumber(value: 1)

        let request = UNNotificationRequest(
            identifier: "new-video-\(video.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            // Ignore failures
        }

        // Optionally try to attach a thumbnail (best-effort)
        if let url = video.thumbnailURL {
            Task.detached(priority: .utility) {
                do {
                    var req = URLRequest(url: url)
                    req.setValue("image/*", forHTTPHeaderField: "Accept")
                    let (data, response) = try await URLSession.shared.data(for: req)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("thumb-\(video.id).jpg")
                    try? FileManager.default.removeItem(at: tmpURL)
                    try data.write(to: tmpURL)
                    let attachment = try UNNotificationAttachment(identifier: "thumb", url: tmpURL)

                    let updated = UNMutableNotificationContent()
                    updated.title = content.title
                    updated.body = content.body
                    updated.sound = content.sound
                    updated.badge = content.badge
                    updated.attachments = [attachment]

                    let updatedRequest = UNNotificationRequest(
                        identifier: "new-video-\(video.id)",
                        content: updated,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    )
                    try? await center.add(updatedRequest)
                } catch { }
            }
        }
    }
}


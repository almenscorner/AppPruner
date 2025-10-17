//
//  notificationService.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation
import UserNotifications

final class NotificationService {
	func sendNow(
		title: String,
		body: String,
		subtitle: String? = nil,
		imagePath: String? = nil,
		playSound: Bool = true,
		interruptionLevel: String? = nil
	) {
		let timeoutSeconds: TimeInterval = 10
		let center = UNUserNotificationCenter.current()
		let group = DispatchGroup()
		group.enter()

		// 1) Request authorization (no prompt if already granted)
		center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
			if let err = err {
				AppLog.error("Notification auth error: \(err.localizedDescription)")
			}
			guard granted else {
				AppLog.error("Notifications not granted. Enable in System Settings → Notifications.")
				group.leave()
				return
			}

			// 2) Build notification content
			let content = UNMutableNotificationContent()
			content.title = title
			content.body  = body
			if let subtitle { content.subtitle = subtitle }
			if playSound { content.sound = .default }
			if interruptionLevel != nil {
				switch interruptionLevel! {
				case "critical":
					content.interruptionLevel = .critical
				default:
					content.interruptionLevel = .active
				}
			}

			// 3) Optional attachment (copy to a safe temp location first)
			if let path = imagePath,
			   let tempURL = Self.prepareAttachment(atPath: path),
			   let attachment = try? UNNotificationAttachment(identifier: "att", url: tempURL) {
				content.attachments = [attachment]
			}

			// 4) Deliver immediately (no trigger = now)
			let req = UNNotificationRequest(
				identifier: UUID().uuidString,
				content: content,
				trigger: nil
			)

			center.add(req) { err in
				if let err = err {
					AppLog.error("Failed to schedule notification: \(err.localizedDescription)")
				} else {
					AppLog.debug("Notification sent with title: \(title), and message: \(body)")
				}
				group.leave()
			}
		}

		// 5) Keep the process alive just long enough to finish
		let result = group.wait(timeout: .now() + timeoutSeconds)
		if result == .timedOut {
			AppLog.error("Timed out waiting for notification scheduling (>\(Int(timeoutSeconds))s).")
		}
		// return; caller can exit immediately
	}

	// MARK: - Helpers

	/// Copies the file into the app's temporary directory so UNNotificationAttachment can access it safely.
	private static func prepareAttachment(atPath imagePath: String) -> URL? {
		let srcURL = URL(fileURLWithPath: imagePath)
		let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(srcURL.lastPathComponent)
		do {
			if !FileManager.default.fileExists(atPath: tmpURL.path) {
				try FileManager.default.copyItem(at: srcURL, to: tmpURL)
			}
			return tmpURL
		} catch {
			AppLog.error("Failed to prepare attachment: \(error.localizedDescription)")
			return nil
		}
	}
}

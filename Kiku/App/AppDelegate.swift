import AppKit
import UserNotifications

/// Handles app lifecycle: notification permission, categories, foreground display,
/// and the presence check-in actions (Yes / Snooze / Stop).
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let snoozeMinutes = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationManager.shared.registerCategories()
        // Authorization is requested with context during onboarding (WelcomeSheet)
        // or from Settings — not silently at launch.
    }

    // Show notifications even while Kiku is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // When Kiku is frontmost, presence check-ins are shown as the in-app modal,
        // so suppress the duplicate system banner. Reminders/start nudges still banner.
        let category = notification.request.content.categoryIdentifier
        if category == NotificationManager.presenceCategoryID, NSApp.isActive {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    // Respond to the presence check-in actions.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let eventID = info["eventID"] as? String
        let title = info["title"] as? String ?? "your study block"

        switch response.actionIdentifier {
        case NotificationManager.snoozeAction:
            if let eventID {
                NotificationManager.shared.snoozePresenceCheck(eventID: eventID, title: title, minutes: snoozeMinutes)
            }
        case NotificationManager.stopAction:
            if let eventID {
                NotificationManager.shared.cancelPresenceChecks(eventID: eventID)
            }
        case NotificationManager.neverAction:
            // Permanently disable presence check-ins everywhere.
            UserDefaults.standard.set(false, forKey: "presenceChecksEnabled")
            NotificationManager.shared.cancelAllPresenceChecks()
        case NotificationManager.startFocusAction:
            // "Start focus" tapped on the break-over notification.
            let minutes = UserDefaults.standard.object(forKey: "focusMinutes") as? Int ?? 25
            Task { @MainActor in
                FocusTimer.shared.start(minutes: minutes)
            }
        default:
            break // "Yes" or default tap — just acknowledge.
        }
        completionHandler()
    }
}

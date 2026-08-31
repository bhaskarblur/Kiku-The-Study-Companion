import Foundation
import UserNotifications

/// Schedules local notifications: reminders, start nudges, and presence check-ins.
/// See docs/FRD.md §3.2.
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    static let presenceCategoryID = "KIKU_PRESENCE"
    static let yesAction = "KIKU_YES"
    static let snoozeAction = "KIKU_SNOOZE"
    static let stopAction = "KIKU_STOP"
    static let neverAction = "KIKU_NEVER"

    static let breakOverCategoryID = "KIKU_BREAK_OVER"
    static let startFocusAction = "KIKU_START_FOCUS"

    private init() {}

    func registerCategories() {
        let yes = UNNotificationAction(identifier: Self.yesAction, title: "Yes, focusing ✨", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze 10 min", options: [])
        let stop = UNNotificationAction(identifier: Self.stopAction, title: "Stop for today", options: [])
        let never = UNNotificationAction(identifier: Self.neverAction, title: "Never show again", options: [.destructive])
        let presence = UNNotificationCategory(
            identifier: Self.presenceCategoryID,
            actions: [yes, snooze, stop, never],
            intentIdentifiers: [],
            options: []
        )

        let startFocus = UNNotificationAction(identifier: Self.startFocusAction,
                                              title: "Start focus ▶︎", options: [.foreground])
        let breakOver = UNNotificationCategory(
            identifier: Self.breakOverCategoryID,
            actions: [startFocus],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([presence, breakOver])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// How far ahead to schedule notifications for recurring events.
    private let scheduleWindowDays = 14

    /// Schedules reminders, start nudges, skip nudges, and presence check-ins for an event.
    /// Recurring events are expanded across the next `scheduleWindowDays` days.
    func schedule(for event: StudyEvent, interval: Int) {
        cancel(for: event)
        let base = event.id.uuidString

        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: scheduleWindowDays, to: now) ?? now
        let occurrences = RecurrenceEngine.occurrences(of: event,
                                                       in: DateInterval(start: now.addingTimeInterval(-3600), end: windowEnd))

        for (index, occ) in occurrences.enumerated() {
            let suffix = "\(index)"

            // Reminder before start.
            if event.reminderLeadMinutes > 0 {
                let fire = occ.start.addingTimeInterval(TimeInterval(-event.reminderLeadMinutes * 60))
                if fire > now {
                    add(id: "\(base)-reminder-\(suffix)", title: "Coming up: \(event.title)",
                        body: "Starting in \(event.reminderLeadMinutes) min. Ready? 🌱", at: fire)
                }
            }

            // Start nudge.
            if occ.start > now {
                add(id: "\(base)-start-\(suffix)", title: "Time to study ✨",
                    body: "\(event.title) is starting now. You've got this.", at: occ.start)
            }

            // Gentle nudge if the block ends unstudied.
            if occ.end > now {
                add(id: "\(base)-skip-\(suffix)", title: "That block slipped by",
                    body: "\(event.title) went unstudied — want to reschedule? No pressure 💛",
                    at: occ.end.addingTimeInterval(120))
            }

            // Presence check-ins (only for occurrences within the next 24h to stay under the pending limit).
            guard event.presenceCheckEnabled, interval > 0, occ.start < now.addingTimeInterval(86_400) else { continue }
            var fire = occ.start.addingTimeInterval(TimeInterval(interval * 60))
            var p = 0
            while fire < occ.end, p < 12 {
                if fire > now {
                    add(id: "\(base)-presence-\(suffix)-\(p)", title: "Still on it? 👀",
                        body: "A quick check — are you focusing on \(event.title)?",
                        at: fire, category: Self.presenceCategoryID,
                        userInfo: ["eventID": base, "title": event.title])
                }
                fire = fire.addingTimeInterval(TimeInterval(interval * 60))
                p += 1
            }
        }
    }

    /// Cancels only the pending presence check-ins for an event (used by the "Stop" action).
    func cancelPresenceChecks(eventID base: String) {
        center.removePendingNotificationRequests(withIdentifiers: presenceIDs(base: base))
    }

    /// Schedules a single snoozed presence check-in a few minutes out.
    func snoozePresenceCheck(eventID base: String, title: String, minutes: Int) {
        let fire = Date().addingTimeInterval(TimeInterval(minutes * 60))
        add(id: "\(base)-presence-snooze-\(Int(fire.timeIntervalSince1970))",
            title: "Still on it? 👀",
            body: "Back to it — are you focusing on \(title)?",
            at: fire, category: Self.presenceCategoryID,
            userInfo: ["eventID": base, "title": title])
    }

    /// Synchronously removes all notification IDs this event could have scheduled.
    /// Deterministic (no async query) so it can safely run right before re-scheduling.
    func cancel(for event: StudyEvent) {
        center.removePendingNotificationRequests(withIdentifiers: allIDs(base: event.id.uuidString))
    }

    /// Cancels just the skip nudges (called when a session is logged for the event).
    func cancelSkipNudge(eventID base: String) {
        let ids = (0..<Self.maxOccurrenceIDs).map { "\(base)-skip-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static let maxOccurrenceIDs = 64

    private func presenceIDs(base: String) -> [String] {
        var ids: [String] = []
        for i in 0..<Self.maxOccurrenceIDs {
            for p in 0..<12 { ids.append("\(base)-presence-\(i)-\(p)") }
        }
        return ids
    }

    private func allIDs(base: String) -> [String] {
        var ids: [String] = []
        for i in 0..<Self.maxOccurrenceIDs {
            ids.append("\(base)-reminder-\(i)")
            ids.append("\(base)-start-\(i)")
            ids.append("\(base)-skip-\(i)")
        }
        return ids + presenceIDs(base: base)
    }

    /// Removes every pending presence check-in across all events (used by "Never show again").
    func cancelAllPresenceChecks() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.contains("-presence") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Delivers a notification immediately (e.g. focus complete / break over).
    func fireNow(title: String, body: String, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        if let category { content.categoryIdentifier = category }
        center.add(UNNotificationRequest(identifier: "now-\(UUID().uuidString)", content: content, trigger: nil))
    }

    /// Fires a test notification after `seconds` so the user can verify delivery
    /// (permission + Do Not Disturb + banner style) end-to-end.
    func sendTest(after seconds: TimeInterval = 8) {
        let content = UNMutableNotificationContent()
        content.title = "Kiku test \u{1F38F}"
        content.body = "If you can see this, notifications work! Your study reminders will arrive like this."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: "kiku-test", content: content, trigger: trigger)) { error in
            if let error { print("[Kiku] test notification error: \(error)") }
        }
    }

    private func add(id: String, title: String, body: String, at date: Date, category: String? = nil, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        if let category { content.categoryIdentifier = category }
        if !userInfo.isEmpty { content.userInfo = userInfo }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error { print("[Kiku] schedule error for \(id): \(error)") }
        }
    }
}

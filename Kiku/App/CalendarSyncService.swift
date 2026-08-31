import Foundation
import EventKit

/// Mirrors Kiku study blocks into the macOS Calendar via EventKit.
/// Because a Google account added in System Settings → Internet Accounts shows up
/// here as a writable calendar, this is how study events reach her phone. See FRD §3.7.
@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()

    @Published var authorized = false
    @Published var calendars: [EKCalendar] = []

    private init() {
        refreshAuthorization()
    }

    func refreshAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorized = (status == .fullAccess)
        if authorized { loadCalendars() }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorized = granted
            if granted { loadCalendars() }
            return granted
        } catch {
            authorized = false
            return false
        }
    }

    /// Writable calendars the user can mirror into (includes Google if added to macOS).
    func loadCalendars() {
        calendars = store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func calendar(withID id: String?) -> EKCalendar? {
        guard let id else { return store.defaultCalendarForNewEvents }
        return calendars.first { $0.calendarIdentifier == id } ?? store.defaultCalendarForNewEvents
    }

    /// Creates or updates the mirrored EventKit event. Returns its identifier.
    @discardableResult
    func mirror(_ event: StudyEvent, toCalendarID calendarID: String?) -> String? {
        guard authorized else { return nil }
        guard let calendar = calendar(withID: calendarID) else { return nil }

        let ekEvent: EKEvent
        if let existingID = event.ekIdentifier, let found = store.event(withIdentifier: existingID) {
            ekEvent = found
        } else {
            ekEvent = EKEvent(eventStore: store)
        }

        ekEvent.title = "📚 \(event.title)"
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.notes = event.notes.isEmpty ? "Scheduled with Kiku" : event.notes
        ekEvent.calendar = calendar
        ekEvent.recurrenceRules = recurrenceRules(for: event.recurrence)

        if event.reminderLeadMinutes > 0 {
            ekEvent.alarms = [EKAlarm(relativeOffset: TimeInterval(-event.reminderLeadMinutes * 60))]
        }

        do {
            try store.save(ekEvent, span: .futureEvents)
            return ekEvent.eventIdentifier
        } catch {
            return nil
        }
    }

    /// Removes the mirrored EventKit event.
    func remove(_ event: StudyEvent) {
        guard authorized, let id = event.ekIdentifier, let ekEvent = store.event(withIdentifier: id) else { return }
        try? store.remove(ekEvent, span: .futureEvents)
    }

    private func recurrenceRules(for recurrence: Recurrence) -> [EKRecurrenceRule]? {
        switch recurrence {
        case .none:
            return nil
        case .daily:
            return [EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)]
        case .weekly:
            return [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)]
        case .weekdays:
            let days: [EKRecurrenceDayOfWeek] = [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)]
            return [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                                     daysOfTheWeek: days, daysOfTheMonth: nil,
                                     monthsOfTheYear: nil, weeksOfTheYear: nil,
                                     daysOfTheYear: nil, setPositions: nil, end: nil)]
        }
    }
}

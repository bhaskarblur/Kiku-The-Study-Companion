import Foundation

/// A single concrete occurrence of a (possibly recurring) StudyEvent within a date range.
struct EventOccurrence: Identifiable {
    let event: StudyEvent
    let start: Date
    let end: Date

    var id: String { "\(event.id.uuidString)-\(Int(start.timeIntervalSince1970))" }

    var title: String { event.title }
    var colorHex: String { event.colorHex }
    var subject: Subject? { event.subject }
    var notes: String { event.notes }
    var recurrence: Recurrence { event.recurrence }
    var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    /// Sessions logged for this event on this occurrence's day.
    var sessionsOnDay: [StudySession] {
        event.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: start) }
    }

    var isCompleted: Bool { !sessionsOnDay.isEmpty }
    var wasSkipped: Bool { end < .now && sessionsOnDay.isEmpty }
}

/// Expands recurring events into concrete occurrences for a given window.
enum RecurrenceEngine {
    private static let maxOccurrences = 400

    static func occurrences(of events: [StudyEvent],
                            in interval: DateInterval,
                            calendar: Calendar = .current) -> [EventOccurrence] {
        var result: [EventOccurrence] = []
        for event in events {
            result.append(contentsOf: occurrences(of: event, in: interval, calendar: calendar))
        }
        return result.sorted { $0.start < $1.start }
    }

    static func occurrences(of event: StudyEvent,
                            in interval: DateInterval,
                            calendar: Calendar = .current) -> [EventOccurrence] {
        let duration = event.end.timeIntervalSince(event.start)

        switch event.recurrence {
        case .none:
            guard event.start <= interval.end, event.end >= interval.start else { return [] }
            return [EventOccurrence(event: event, start: event.start, end: event.end)]

        case .daily, .weekdays, .weekly:
            let step: Int = event.recurrence == .weekly ? 7 : 1
            var occurrences: [EventOccurrence] = []

            // Fast-forward to the first candidate at/after the window start.
            var cursor = event.start
            if cursor < interval.start {
                let secondsPerStep = Double(step) * 86_400
                let elapsed = interval.start.timeIntervalSince(cursor)
                let jumps = floor(elapsed / secondsPerStep)
                cursor = calendar.date(byAdding: .day, value: Int(jumps) * step, to: cursor) ?? cursor
            }

            var guardCount = 0
            while cursor <= interval.end, guardCount < maxOccurrences {
                guardCount += 1
                let occEnd = cursor.addingTimeInterval(duration)
                let includeDay: Bool
                if event.recurrence == .weekdays {
                    let weekday = calendar.component(.weekday, from: cursor)
                    includeDay = weekday != 1 && weekday != 7 // exclude Sun(1)/Sat(7)
                } else {
                    includeDay = true
                }
                if includeDay, occEnd >= interval.start, cursor >= event.start {
                    occurrences.append(EventOccurrence(event: event, start: cursor, end: occEnd))
                }
                cursor = calendar.date(byAdding: .day, value: step, to: cursor) ?? cursor.addingTimeInterval(Double(step) * 86_400)
            }
            return occurrences
        }
    }

    /// Convenience: occurrences on a single day.
    static func occurrences(of events: [StudyEvent], on day: Date, calendar: Calendar = .current) -> [EventOccurrence] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return occurrences(of: events, in: DateInterval(start: start, end: end), calendar: calendar)
    }
}

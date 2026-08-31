import Foundation

/// Pure functions for computing study metrics from sessions/events.
enum StudyStats {
    static func minutes(on day: Date, sessions: [StudySession], calendar: Calendar = .current) -> Int {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusMinutes }
    }

    static func minutesThisWeek(_ sessions: [StudySession], calendar: Calendar = .current, now: Date = .now) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions
            .filter { week.contains($0.startedAt) }
            .reduce(0) { $0 + $1.focusMinutes }
    }

    static func sessionsThisWeek(_ sessions: [StudySession], calendar: Calendar = .current, now: Date = .now) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.filter { week.contains($0.startedAt) }.count
    }

    /// Consecutive days (ending today or yesterday) with at least one session.
    static func currentStreak(_ sessions: [StudySession], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        // Allow the streak to still count if today has no session yet but yesterday did.
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !days.contains(cursor) { return 0 }
        }
        while days.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    /// Minutes per day for the last `days` days, oldest first.
    static func dailyMinutes(_ sessions: [StudySession], days: Int, calendar: Calendar = .current, now: Date = .now) -> [(date: Date, minutes: Int)] {
        (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
            return (day, minutes(on: day, sessions: sessions, calendar: calendar))
        }
    }
}

extension Int {
    /// Formats a minute count like "1h 25m" or "40m".
    var minutesLabel: String {
        if self >= 60 {
            let h = self / 60, m = self % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(self)m"
    }
}

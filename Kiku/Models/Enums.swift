import Foundation

// MARK: - Recurrence

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekdays
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Does not repeat"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Every week"
        }
    }
}

// MARK: - Session source

enum SessionSource: String, Codable {
    case pomodoro
    case manual
}

// MARK: - Goal type

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case dailyMinutes
    case weeklyMinutes
    case weeklySessions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dailyMinutes: return "Daily minutes"
        case .weeklyMinutes: return "Weekly minutes"
        case .weeklySessions: return "Weekly sessions"
        }
    }
}

// MARK: - Appearance

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

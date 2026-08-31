import SwiftUI

/// App-level preferences persisted in UserDefaults. See docs/FRD.md §3.8.
@MainActor
final class SettingsStore: ObservableObject {
    @AppStorage("appearanceMode") var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("focusMinutes") var focusMinutes: Int = 25
    @AppStorage("shortBreakMinutes") var shortBreakMinutes: Int = 5
    @AppStorage("longBreakMinutes") var longBreakMinutes: Int = 15
    @AppStorage("defaultReminderLead") var defaultReminderLead: Int = 10
    @AppStorage("dailyMinutesTarget") var dailyMinutesTarget: Int = 60
    @AppStorage("weeklyMinutesTarget") var weeklyMinutesTarget: Int = 300
    @AppStorage("presenceCheckDefault") var presenceCheckDefault: Bool = true
    /// Global kill switch for presence check-ins ("never show again").
    @AppStorage("presenceChecksEnabled") var presenceChecksEnabled: Bool = true
    @AppStorage("presenceIntervalMinutes") var presenceIntervalMinutes: Int = 10
    @AppStorage("hasSeededSubjects") var hasSeededSubjects: Bool = false
    @AppStorage("hasSeededGeminiKey") var hasSeededGeminiKey: Bool = false
    @AppStorage("hasSeenWelcome") var hasSeenWelcome: Bool = false
    @AppStorage("calendarSyncEnabled") var calendarSyncEnabled: Bool = false
    @AppStorage("calendarSyncID") var calendarSyncID: String = ""
    @AppStorage("geminiAPIKey") var geminiAPIKey: String = ""
    @AppStorage("quietHoursEnabled") var quietHoursEnabled: Bool = false
    @AppStorage("quietStartHour") var quietStartHour: Int = 22
    @AppStorage("quietEndHour") var quietEndHour: Int = 7

    /// True if the given date falls within the configured quiet-hours window.
    func isQuiet(at date: Date = .now) -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        if quietStartHour == quietEndHour { return false }
        if quietStartHour < quietEndHour {
            return hour >= quietStartHour && hour < quietEndHour
        } else {
            // Window wraps past midnight (e.g. 22 → 7).
            return hour >= quietStartHour || hour < quietEndHour
        }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

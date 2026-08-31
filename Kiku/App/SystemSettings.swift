import AppKit

/// Opens specific macOS System Settings panes so we can guide the user directly.
enum SystemSettings {
    /// System Settings → Internet Accounts (to add a Google account).
    static func openInternetAccounts() {
        open([
            "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.internetaccounts"
        ])
    }

    /// System Settings → Privacy & Security → Calendars.
    static func openCalendarPrivacy() {
        open([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
        ])
    }

    /// System Settings → Notifications.
    static func openNotifications() {
        open([
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ])
    }

    /// Opens a web URL (e.g. to get a Gemini API key).
    static func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }

    /// Tries each candidate URL until one opens.
    private static func open(_ candidates: [String]) {
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
}

import SwiftUI
import UserNotifications

/// First-run onboarding that warmly guides the user through the permissions Kiku
/// needs — notifications and calendar/Google sync — with clear context and buttons.
struct WelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var sync = CalendarSyncService.shared

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var page = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            header

            VStack(spacing: Theme.Spacing.md) {
                notificationsCard
                calendarCard
            }

            VStack(spacing: Theme.Spacing.sm) {
                KPrimaryButton(title: "Start studying ✨", icon: "sparkles", fullWidth: true) { finish() }
                Button("Maybe later") { finish() }
                    .buttonStyle(.plain).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 480)
        .background(Theme.Palette.bg)
        .task {
            NotificationManager.shared.registerCategories()
            notifStatus = await NotificationManager.shared.authorizationStatus()
            sync.refreshAuthorization()
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image("KikuLogo")
                .resizable().interpolation(.high)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            Text("Welcome to Kiku 🎐").font(.kLargeTitle).foregroundStyle(Theme.Palette.textPrimary)
            Text("Your cozy study companion. Two quick things and you're all set 💛")
                .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        permissionCard(
            icon: "bell.badge.fill",
            title: "Turn on notifications",
            subtitle: "Gentle reminders before each block and kind nudges if you drift — so you never miss study time."
        ) {
            switch notifStatus {
            case .authorized, .provisional, .ephemeral:
                statusBadge("Enabled", color: Theme.Palette.success)
            case .denied:
                KSecondaryButton(title: "Open settings", icon: "arrow.up.right") {
                    SystemSettings.openNotifications()
                }
            default:
                KPrimaryButton(title: "Enable", icon: "bell.fill") {
                    Task {
                        _ = await NotificationManager.shared.requestAuthorization()
                        notifStatus = await NotificationManager.shared.authorizationStatus()
                    }
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        permissionCard(
            icon: "calendar.badge.clock",
            title: "Connect your calendar & phone",
            subtitle: "Mirror study blocks to macOS Calendar. Add a Google account and they'll appear on your phone automatically, with reminders."
        ) {
            if sync.authorized && settings.calendarSyncEnabled {
                statusBadge("Connected", color: Theme.Palette.success)
            } else {
                VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
                    KPrimaryButton(title: "Connect", icon: "arrow.triangle.2.circlepath") {
                        Task {
                            let granted = await sync.requestAccess()
                            settings.calendarSyncEnabled = granted
                        }
                    }
                    Button {
                        SystemSettings.openInternetAccounts()
                    } label: {
                        Label("Add Google account", systemImage: "globe")
                            .font(.kCaption).foregroundStyle(Theme.Palette.accent)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Building blocks

    private func permissionCard<Trailing: View>(icon: String, title: String, subtitle: String,
                                                @ViewBuilder trailing: () -> Trailing) -> some View {
        let control = trailing()
        return KCard(padding: Theme.Spacing.lg) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title).font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                control
            }
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
            Text(text).font(.kCaption).foregroundStyle(color)
        }
    }

    private func finish() {
        settings.hasSeenWelcome = true
        dismiss()
    }
}

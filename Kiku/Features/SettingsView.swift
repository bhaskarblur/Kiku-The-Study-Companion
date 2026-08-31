import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.modelContext) private var context
    @ObservedObject private var sync = CalendarSyncService.shared
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var editingSubject: Subject?
    @State private var creatingSubject = false
    @State private var testSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Settings").font(.kLargeTitle).foregroundStyle(Theme.Palette.textPrimary)

                section("Appearance") {
                    row("Theme") {
                        Picker("", selection: Binding(
                            get: { settings.appearanceMode },
                            set: { settings.appearanceMode = $0 })) {
                            ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().pickerStyle(.segmented).frame(width: 220)
                    }
                }

                subjectsSection

                section("Focus defaults") {
                    stepperRow("Focus length", value: $settings.focusMinutes, range: 5...90, unit: "min")
                    stepperRow("Short break", value: $settings.shortBreakMinutes, range: 1...30, unit: "min")
                    stepperRow("Long break", value: $settings.longBreakMinutes, range: 5...60, unit: "min")
                }

                section("Goals") {
                    stepperRow("Daily target", value: $settings.dailyMinutesTarget, range: 5...600, step: 5, unit: "min")
                    stepperRow("Weekly target", value: $settings.weeklyMinutesTarget, range: 30...3000, step: 30, unit: "min")
                }

                section("Reminders & nudges") {
                    stepperRow("Default reminder", value: $settings.defaultReminderLead, range: 0...60, step: 5, unit: "min before")
                    row("Presence check-ins") {
                        Toggle("", isOn: $settings.presenceChecksEnabled).labelsHidden()
                            .toggleStyle(.switch).tint(Theme.Palette.accent)
                    }
                    row("Presence check-in by default") {
                        Toggle("", isOn: $settings.presenceCheckDefault).labelsHidden()
                            .toggleStyle(.switch).tint(Theme.Palette.accent)
                            .disabled(!settings.presenceChecksEnabled)
                    }
                    stepperRow("Check-in interval", value: $settings.presenceIntervalMinutes, range: 5...30, step: 5, unit: "min")
                    row("Quiet hours") {
                        Toggle("", isOn: $settings.quietHoursEnabled).labelsHidden()
                            .toggleStyle(.switch).tint(Theme.Palette.accent)
                    }
                    if settings.quietHoursEnabled {
                        stepperRow("Quiet from", value: $settings.quietStartHour, range: 0...23, unit: ":00")
                        stepperRow("Quiet until", value: $settings.quietEndHour, range: 0...23, unit: ":00")
                    }
                }

                calendarSyncSection

                section("Permissions") {
                    row("Notifications") {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(notifStatusLabel).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                            if notifStatus == .authorized {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.success)
                            } else if notifStatus == .denied {
                                KSecondaryButton(title: "Open settings", icon: "bell.badge") {
                                    SystemSettings.openNotifications()
                                }
                            } else {
                                KSecondaryButton(title: "Enable") { requestNotifications() }
                            }
                        }
                    }
                    if notifStatus == .denied {
                        Label("Reminders and gentle nudges are off. Turn on Kiku notifications so study blocks can reach you.",
                              systemImage: "info.circle")
                            .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if notifStatus == .authorized {
                        Divider().overlay(Theme.Palette.border)
                        row("Test it") {
                            KSecondaryButton(title: "Send test", icon: "paperplane.fill") {
                                NotificationManager.shared.sendTest()
                                withAnimation { testSent = true }
                            }
                        }
                        if testSent {
                            Label("Sent! Switch to another app — a banner should pop in ~8 seconds. If nothing appears, open System Settings → Notifications → Kiku, allow alerts (Banners/Alerts), and turn off Do Not Disturb / Focus.",
                                  systemImage: "sparkles")
                                .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                section("About") {
                    row("Version") { Text("1.0.0").font(.kCaption).foregroundStyle(Theme.Palette.textSecondary) }
                    Text("Your calm, cute study companion for productive, joyful days 💛")
                        .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task {
            NotificationManager.shared.registerCategories()
            notifStatus = await NotificationManager.shared.authorizationStatus()
            sync.refreshAuthorization()
        }
        .sheet(isPresented: $creatingSubject) { SubjectEditorSheet() }
        .sheet(item: $editingSubject) { SubjectEditorSheet(subject: $0) }
    }

    // MARK: - Subjects

    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("SUBJECTS").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button { creatingSubject = true } label: {
                    Label("Add", systemImage: "plus").font(.kCaption).foregroundStyle(Theme.Palette.accent)
                }.buttonStyle(.plain)
            }
            KCard(padding: Theme.Spacing.md) {
                VStack(spacing: Theme.Spacing.sm) {
                    if subjects.isEmpty {
                        Text("No subjects yet — add French, Grammar, Vocabulary…")
                            .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(subjects) { subject in
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: subject.icon).font(.system(size: 13))
                                .foregroundStyle(Color(hex: subject.colorHex)).frame(width: 18)
                            Text(subject.name).font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Button { editingSubject = subject } label: {
                                Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
                            }.buttonStyle(.plain)
                            Button { context.delete(subject) } label: {
                                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.Palette.warning)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Calendar sync

    private var calendarSyncSection: some View {
        section("Calendar sync (reaches her phone)") {
            row("Sync to macOS Calendar") {
                Toggle("", isOn: Binding(
                    get: { settings.calendarSyncEnabled },
                    set: { enable in
                        if enable {
                            Task {
                                let granted = await sync.requestAccess()
                                settings.calendarSyncEnabled = granted
                            }
                        } else {
                            settings.calendarSyncEnabled = false
                        }
                    })).labelsHidden().toggleStyle(.switch).tint(Theme.Palette.accent)
            }

            if settings.calendarSyncEnabled && sync.authorized {
                row("Target calendar") {
                    Picker("", selection: $settings.calendarSyncID) {
                        Text("Default").tag("")
                        ForEach(sync.calendars, id: \.calendarIdentifier) { cal in
                            Text(cal.title).tag(cal.calendarIdentifier)
                        }
                    }.labelsHidden().pickerStyle(.menu).frame(width: 220)
                }
                Label("Connected! Study blocks now appear on any device signed into this calendar.",
                      systemImage: "checkmark.seal.fill")
                    .font(.kCaption).foregroundStyle(Theme.Palette.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if settings.calendarSyncEnabled && !sync.authorized {
                calendarDeniedHelp
            }

            Divider().overlay(Theme.Palette.border)
            googleSetupGuide
        }
    }

    private var calendarDeniedHelp: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("macOS hasn't granted Kiku calendar access yet.", systemImage: "exclamationmark.triangle.fill")
                .font(.kCaption).foregroundStyle(Theme.Palette.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
            KSecondaryButton(title: "Open Calendar privacy settings", icon: "hand.raised.fill") {
                SystemSettings.openCalendarPrivacy()
            }
        }
    }

    private var googleSetupGuide: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Connect Google Calendar (one-time setup)", systemImage: "sparkles")
                .font(.kBody.weight(.semibold)).foregroundStyle(Theme.Palette.textPrimary)

            setupStep(1, icon: "person.crop.circle.badge.plus",
                      "Add your Google account to your Mac and turn on Calendars.")
            KSecondaryButton(title: "Open Internet Accounts", icon: "globe") {
                SystemSettings.openInternetAccounts()
            }
            setupStep(2, icon: "arrow.triangle.2.circlepath",
                      "Turn on \u{201C}Sync to macOS Calendar\u{201D} above, then tap Allow when macOS asks.")
            setupStep(3, icon: "calendar.badge.checkmark",
                      "Pick your Google calendar in the \u{201C}Target calendar\u{201D} dropdown.")
            setupStep(4, icon: "iphone",
                      "Done! Every block you add, edit, or move shows up on your phone with reminders.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupStep(_ number: Int, icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(number)")
                .font(.kNumber(12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.Palette.accent).clipShape(Circle())
            Image(systemName: icon).font(.system(size: 13))
                .foregroundStyle(Theme.Palette.accent).frame(width: 18)
            Text(text).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - AI recap

    // The Gemini API key is a developer concern, seeded on first launch — no user-facing UI.

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let inner = content()
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            KCard(padding: Theme.Spacing.md) {
                VStack(spacing: Theme.Spacing.md) { inner }
            }
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label).font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            trailing()
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: String) -> some View {
        row(label) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(value.wrappedValue) \(unit)").font(.kNumber(13)).foregroundStyle(Theme.Palette.textSecondary)
                Stepper("", value: value, in: range, step: step).labelsHidden()
            }
        }
    }

    private var notifStatusLabel: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return "Enabled"
        case .denied: return "Denied — enable in System Settings"
        default: return "Not enabled"
        }
    }

    private func requestNotifications() {
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            notifStatus = await NotificationManager.shared.authorizationStatus()
        }
    }
}

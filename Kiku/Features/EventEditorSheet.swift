import SwiftUI
import SwiftData

struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    /// If nil, we are creating a new event.
    var event: StudyEvent?
    var defaultStart: Date = .now

    @State private var title = ""
    @State private var subject: Subject?
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)
    @State private var recurrence: Recurrence = .none
    @State private var reminderLead = 10
    @State private var presenceCheck = false
    @State private var notes = ""

    private var isEditing: Bool { event != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit study block" : "New study block")
                    .font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(Theme.Spacing.xl)

            Divider().overlay(Theme.Palette.border)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    field("Title") {
                        TextField("e.g. French vocabulary", text: $title)
                            .textFieldStyle(.plain)
                            .font(.kBody)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Palette.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    }

                    field("Subject") {
                        subjectPicker
                    }

                    field("Day") {
                        KDateField(date: dateBinding)
                    }

                    HStack(spacing: Theme.Spacing.lg) {
                        field("Starts at") {
                            DatePicker("", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact)
                        }
                        field("Ends at") {
                            DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact)
                        }
                    }

                    field("How long?") {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach([30, 60, 90, 120], id: \.self) { durationChip($0) }
                        }
                    }

                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "calendar.badge.clock").font(.system(size: 11))
                        Text(summaryText)
                    }
                    .font(.kCaption).foregroundStyle(Theme.Palette.accent)

                    field("Repeat") {
                        Picker("", selection: $recurrence) {
                            ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().pickerStyle(.menu)
                    }

                    field("Remind me before") {
                        Picker("", selection: $reminderLead) {
                            Text("At start").tag(0)
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                        }.labelsHidden().pickerStyle(.menu)
                    }

                    Toggle(isOn: $presenceCheck) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Presence check-in").font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
                            Text("While you study, Kiku gently pops a “still focusing?” check every \(settings.presenceIntervalMinutes) min so you don’t quietly drift off. Tap Yes to keep going, Snooze for a short break, or turn it off right from the popup.")
                                .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Theme.Palette.accent)

                    field("Notes") {
                        TextEditor(text: $notes)
                            .font(.kBody)
                            .frame(height: 70)
                            .padding(Theme.Spacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(Theme.Palette.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    }
                }
                .padding(Theme.Spacing.xl)
            }

            Divider().overlay(Theme.Palette.border)

            HStack {
                if isEditing {
                    Button(role: .destructive) { deleteEvent() } label: {
                        Label("Delete", systemImage: "trash")
                    }.buttonStyle(.plain).foregroundStyle(Theme.Palette.warning)
                }
                Spacer()
                KSecondaryButton(title: "Cancel") { dismiss() }
                KPrimaryButton(title: "Save", icon: "checkmark") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: 460, height: 620)
        .background(Theme.Palette.bg)
        .onAppear(perform: load)
    }

    private var subjectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(subjects) { s in
                    let selected = subject?.id == s.id
                    Button {
                        subject = s
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle().fill(Color(hex: s.colorHex)).frame(width: 8, height: 8)
                            Text(s.name).font(.kCaption)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .background(selected ? Color(hex: s.colorHex).opacity(0.18) : Theme.Palette.surfaceAlt)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(selected ? Color(hex: s.colorHex) : .clear, lineWidth: 1.5))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            content()
        }
    }

    // MARK: - Friendly date/time helpers

    /// Changes the day while keeping the chosen times (moves start and end together).
    private var dateBinding: Binding<Date> {
        Binding(
            get: { start },
            set: { newDay in
                let cal = Calendar.current
                let duration = end.timeIntervalSince(start)
                let time = cal.dateComponents([.hour, .minute], from: start)
                var dc = cal.dateComponents([.year, .month, .day], from: newDay)
                dc.hour = time.hour; dc.minute = time.minute
                if let newStart = cal.date(from: dc) {
                    start = newStart
                    end = newStart.addingTimeInterval(duration)
                }
            }
        )
    }

    /// Sets the start time; nudges the end forward if it would end up before the start.
    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { start },
            set: { newStart in
                let duration = max(15 * 60, end.timeIntervalSince(start))
                start = newStart
                if end <= newStart { end = newStart.addingTimeInterval(duration) }
            }
        )
    }

    /// Sets the end time; keeps it at least 15 min after the start.
    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { end },
            set: { newEnd in
                end = newEnd <= start ? start.addingTimeInterval(15 * 60) : newEnd
            }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = Int(end.timeIntervalSince(start) / 60) == minutes
        return Button {
            end = start.addingTimeInterval(TimeInterval(minutes * 60))
        } label: {
            Text(minutes.minutesLabel)
                .font(.kCaption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs + 1)
                .foregroundStyle(selected ? .white : Theme.Palette.textSecondary)
                .background(selected ? Theme.Palette.accent : Theme.Palette.surfaceAlt)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        let day = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let s = start.formatted(date: .omitted, time: .shortened)
        let e = end.formatted(date: .omitted, time: .shortened)
        let dur = max(0, Int(end.timeIntervalSince(start) / 60)).minutesLabel
        return "\(day) · \(s) – \(e) · \(dur)"
    }

    private func load() {
        if let event {
            title = event.title
            subject = event.subject
            start = event.start
            end = event.end
            recurrence = event.recurrence
            reminderLead = event.reminderLeadMinutes
            presenceCheck = event.presenceCheckEnabled
            notes = event.notes
        } else {
            start = defaultStart
            end = defaultStart.addingTimeInterval(3600)
            reminderLead = settings.defaultReminderLead
            presenceCheck = settings.presenceCheckDefault
            subject = subjects.first
        }
    }

    private func save() {
        let color = subject?.colorHex ?? Theme.subjectColors[0]
        if let event {
            event.title = title
            event.subject = subject
            event.start = start
            event.end = end
            event.recurrence = recurrence
            event.reminderLeadMinutes = reminderLead
            event.presenceCheckEnabled = presenceCheck
            event.notes = notes
            event.colorHex = color
            scheduleNotifications(for: event)
            syncToCalendar(event)
        } else {
            let newEvent = StudyEvent(
                title: title, start: start, end: end, notes: notes,
                colorHex: color, reminderLeadMinutes: reminderLead,
                recurrence: recurrence, presenceCheckEnabled: presenceCheck, subject: subject
            )
            context.insert(newEvent)
            scheduleNotifications(for: newEvent)
            syncToCalendar(newEvent)
        }
        dismiss()
    }

    /// Requests notification permission (if not yet asked) so reminders actually fire,
    /// then schedules them.
    private func scheduleNotifications(for event: StudyEvent) {
        let interval = presenceInterval
        Task {
            let status = await NotificationManager.shared.authorizationStatus()
            if status == .notDetermined {
                _ = await NotificationManager.shared.requestAuthorization()
            }
            NotificationManager.shared.schedule(for: event, interval: interval)
        }
    }

    /// Presence interval to schedule with, honoring the global kill switch.
    private var presenceInterval: Int {
        settings.presenceChecksEnabled ? settings.presenceIntervalMinutes : 0
    }

    private func syncToCalendar(_ event: StudyEvent) {
        guard settings.calendarSyncEnabled else { return }
        let calendarID = settings.calendarSyncID.isEmpty ? nil : settings.calendarSyncID
        if let identifier = CalendarSyncService.shared.mirror(event, toCalendarID: calendarID) {
            event.ekIdentifier = identifier
        }
    }

    private func deleteEvent() {
        if let event {
            NotificationManager.shared.cancel(for: event)
            if settings.calendarSyncEnabled { CalendarSyncService.shared.remove(event) }
            context.delete(event)
        }
        dismiss()
    }
}

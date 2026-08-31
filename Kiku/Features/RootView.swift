import SwiftUI
import SwiftData

enum KikuSection: String, CaseIterable, Identifiable {
    case today, calendar, focus, stats, journal, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .focus: return "Focus"
        case .stats: return "Stats"
        case .journal: return "Journal"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .calendar: return "calendar"
        case .focus: return "timer"
        case .stats: return "chart.bar.fill"
        case .journal: return "book.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var focusTimer: FocusTimer
    @Query(sort: \StudyEvent.start) private var events: [StudyEvent]
    @State private var selection: KikuSection = .today

    // Presence check-in state.
    @State private var presencePrompt: EventOccurrence?
    @State private var lastPromptTimes: [String: Date] = [:]
    @State private var suppressedToday: Set<String> = []
    @State private var showWelcome = false
    private let presenceTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selection {
                case .today: TodayView(selection: $selection)
                case .calendar: CalendarView()
                case .focus: FocusView()
                case .stats: StatsView()
                case .journal: JournalView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bg)
        }
        .task {
            seedIfNeeded()
            showWelcome = !settings.hasSeenWelcome
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet()
                .environmentObject(settings)
                .interactiveDismissDisabled(true)
        }
        .overlay {
            if let occ = presencePrompt {
                PresenceCheckOverlay(
                    occurrence: occ,
                    onYes: { dismissPrompt(occ) },
                    onSnooze: {
                        // Push the next check-in one interval out.
                        lastPromptTimes[occ.id] = Date()
                        presencePrompt = nil
                    },
                    onStopToday: {
                        suppressedToday.insert(occ.id)
                        presencePrompt = nil
                    },
                    onNever: {
                        settings.presenceChecksEnabled = false
                        presencePrompt = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(Theme.Motion.spring, value: presencePrompt?.id)
        .onReceive(presenceTicker) { _ in evaluatePresenceCheck() }
        .sheet(item: $focusTimer.pendingLog, onDismiss: { startBreakAfterFocus() }) { log in
            SessionLogSheet(focusMinutes: log.minutes,
                            suggestedSubject: linkedEvent(for: log)?.subject,
                            linkedEvent: linkedEvent(for: log))
        }
    }

    /// After a focus session is logged, roll into a short break (long break every 4th session).
    private func startBreakAfterFocus() {
        let count = focusTimer.completedFocusSessions
        let isLong = count > 0 && count % 4 == 0
        focusTimer.startBreak(minutes: isLong ? settings.longBreakMinutes : settings.shortBreakMinutes)
    }

    private func linkedEvent(for log: PendingLog) -> StudyEvent? {
        guard let id = log.eventID else { return nil }
        return events.first { $0.id == id }
    }

    // MARK: - Presence check-in

    private func evaluatePresenceCheck() {
        guard settings.presenceChecksEnabled, presencePrompt == nil else { return }
        guard !settings.isQuiet() else { return }
        // Only show the in-app modal when Kiku is frontmost. If she's in another app
        // (e.g. Chrome), the macOS system notification banner reaches her instead.
        guard NSApplication.shared.isActive else { return }

        let now = Date()
        let interval = TimeInterval(max(1, settings.presenceIntervalMinutes) * 60)
        let current = RecurrenceEngine.occurrences(of: events, on: now).first { occ in
            occ.event.presenceCheckEnabled
                && occ.start <= now && occ.end > now
                && !occ.isCompleted
                && !suppressedToday.contains(occ.id)
        }
        guard let occ = current else { return }

        // Only prompt once per interval, and not immediately at the very start.
        let elapsed = now.timeIntervalSince(occ.start)
        guard elapsed >= interval else { return }
        if let last = lastPromptTimes[occ.id], now.timeIntervalSince(last) < interval { return }

        lastPromptTimes[occ.id] = now
        presencePrompt = occ
    }

    private func dismissPrompt(_ occ: EventOccurrence) {
        lastPromptTimes[occ.id] = Date()
        presencePrompt = nil
    }

    private func seedIfNeeded() {
        if !settings.hasSeededGeminiKey && settings.geminiAPIKey.isEmpty {
            settings.geminiAPIKey = GeminiDefaults.seededKey
            settings.hasSeededGeminiKey = true
        }
        guard !settings.hasSeededSubjects else { return }
        // Start her off with just French — she can add her own subjects anytime.
        context.insert(Subject(name: "French", colorHex: Theme.subjectColors[0], icon: "text.bubble.fill"))
        settings.hasSeededSubjects = true
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Binding var selection: KikuSection
    @EnvironmentObject private var focusTimer: FocusTimer
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @State private var addingSubject = false
    @State private var editingSubject: Subject?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image("KikuLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.Palette.border, lineWidth: 1))
                Text("Kiku").font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.lg)

            VStack(spacing: 2) {
                ForEach(KikuSection.allCases.filter { $0 != .settings }) { section in
                    NavRow(section: section,
                           isSelected: selection == section,
                           active: section == .focus && focusTimer.isActive) {
                        withAnimation(Theme.Motion.quick) { selection = section }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)

            HStack {
                Text("SUBJECTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button { addingSubject = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .buttonStyle(.plain)
                .help("Add a subject")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xs)

            if subjects.isEmpty {
                Text("Add subjects you’re studying ✨")
                    .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, Theme.Spacing.lg)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(subjects) { subject in
                        Button { editingSubject = subject } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: subject.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: subject.colorHex))
                                    .frame(width: 16)
                                Text(subject.name).font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }

            Spacer()

            NavRow(section: .settings, isSelected: selection == .settings) {
                withAnimation(Theme.Motion.quick) { selection = .settings }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
        }
        .background(Theme.Palette.surface)
        .sheet(isPresented: $addingSubject) { SubjectEditorSheet() }
        .sheet(item: $editingSubject) { SubjectEditorSheet(subject: $0) }
    }
}

private struct NavRow: View {
    let section: KikuSection
    let isSelected: Bool
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textSecondary)
                Text(section.title)
                    .font(.kBody.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                Spacer()
                if active {
                    Circle().fill(Theme.Palette.success).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Theme.Palette.success.opacity(0.3), lineWidth: 3))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 1)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(isSelected ? Theme.Palette.accent.opacity(0.12)
                          : (hovering ? Theme.Palette.surfaceAlt : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

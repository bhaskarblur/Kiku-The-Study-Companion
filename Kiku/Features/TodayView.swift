import SwiftUI
import SwiftData
import UserNotifications

struct TodayView: View {
    @Binding var selection: KikuSection
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var focusTimer: FocusTimer

    @Query(sort: \StudyEvent.start) private var events: [StudyEvent]
    @Query private var sessions: [StudySession]

    @State private var showingEditor = false
    @State private var notifStatus: UNAuthorizationStatus = .authorized
    @State private var celebrate = false

    private var todaysOccurrences: [EventOccurrence] {
        RecurrenceEngine.occurrences(of: events, on: .now)
    }

    private var nextOccurrence: EventOccurrence? {
        todaysOccurrences.first { $0.end > .now } ?? todaysOccurrences.first
    }

    private var todayMinutes: Int { StudyStats.minutes(on: .now, sessions: sessions) }
    private var streak: Int { StudyStats.currentStreak(sessions) }
    private var todaySessions: Int {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }.count
    }

    private var goalMet: Bool {
        settings.dailyMinutesTarget > 0 && todayMinutes >= settings.dailyMinutesTarget
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header

                if goalMet {
                    goalCelebrationBanner
                }

                if notifStatus == .denied || notifStatus == .notDetermined {
                    notificationBanner
                }

                if focusTimer.isActive {
                    focusStatusCard
                }

                HStack(spacing: Theme.Spacing.md) {
                    StatChip(icon: "flame.fill", value: "\(streak)", label: "day streak", tint: Theme.Palette.warning)
                    StatChip(icon: "clock.fill",
                             value: "\(todayMinutes)/\(settings.dailyMinutesTarget)m",
                             label: "today", tint: Theme.Palette.accent)
                    StatChip(icon: "checkmark.seal.fill", value: "\(todaySessions)", label: "sessions", tint: Theme.Palette.success)
                }

                dailyGoalCard
                nextBlockCard

                HStack {
                    Text("Today's schedule").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    Button { showingEditor = true } label: {
                        Label("Add block", systemImage: "plus")
                            .font(.kBody).foregroundStyle(Theme.Palette.accent)
                    }.buttonStyle(.plain)
                }

                if todaysOccurrences.isEmpty {
                    KCard {
                        EmptyState(emoji: "🌱", message: "No blocks today yet.\nAdd one to start a productive day.",
                                   actionTitle: "Add study block") { showingEditor = true }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(todaysOccurrences) { occ in
                            TimelineRow(occurrence: occ) { startFocus(for: occ) }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .animation(Theme.Motion.spring, value: goalMet)
        }
        .sheet(isPresented: $showingEditor) { EventEditorSheet() }
        .task {
            notifStatus = await NotificationManager.shared.authorizationStatus()
        }
    }

    private var notificationBanner: some View {
        KCard(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18)).foregroundStyle(Theme.Palette.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn on notifications").font(.kBody.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("So your study reminders and gentle nudges actually reach you 🔔")
                        .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                KPrimaryButton(title: notifStatus == .denied ? "Open settings" : "Enable", icon: "bell.fill") {
                    if notifStatus == .denied {
                        SystemSettings.openNotifications()
                    } else {
                        Task {
                            _ = await NotificationManager.shared.requestAuthorization()
                            notifStatus = await NotificationManager.shared.authorizationStatus()
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(greeting).font(.kLargeTitle).foregroundStyle(Theme.Palette.textPrimary)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var rewardFood: String {
        let foods = ["Chocolate Brownie", "Truffle Pasta", "Avocado Toast",
                     "Coffee", "Truffle Pastry", "Mushroom Pizza"]
        // Stable for the whole day, changes day to day.
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return foods[day % foods.count]
    }

    private var goalCelebrationBanner: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Text("🎉")
                .font(.system(size: 42))
                .rotationEffect(.degrees(celebrate ? -8 : 8))
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: celebrate)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Daily goal smashed! 🌟")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                Text("You studied \(todayMinutes.minutesLabel) today — you showed up for yourself, and that's everything. So proud of you 💛")
                    .font(.kBody).foregroundStyle(.white.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                Text("YOU DESERVE A \(rewardFood.uppercased()) TODAY")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
                    .padding(.top, 2)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
            Spacer(minLength: Theme.Spacing.md)

            Text("🍰")
                .font(.system(size: 44))
                .scaleEffect(celebrate ? 1.14 : 0.92)
                .rotationEffect(.degrees(celebrate ? 6 : -6))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: celebrate)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "#7C6BF0"), Color(hex: "#9A7CE8"), Color(hex: "#F7C948")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .topTrailing) {
            Text("✨").font(.system(size: 18)).opacity(celebrate ? 0.95 : 0.35)
                .padding(Theme.Spacing.md)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: celebrate)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .shadow(color: Color(hex: "#F7C948").opacity(0.35), radius: 16, y: 6)
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .onAppear { celebrate = true }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning ☀️"
        case 12..<17: return "Good afternoon 🌸"
        case 17..<22: return "Good evening 🌙"
        default: return "Hi there ✨"
        }
    }

    private var dailyGoalCard: some View {
        let progress = min(1, Double(todayMinutes) / Double(max(1, settings.dailyMinutesTarget)))
        return KCard {
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 9, tint: Theme.Palette.success)
                        .frame(width: 64, height: 64)
                    Text("\(Int(progress * 100))%").font(.kNumber(14)).foregroundStyle(Theme.Palette.textPrimary)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Daily goal").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                    Text(progress >= 1
                         ? "Goal smashed 🎉 proud of you."
                         : "\(todayMinutes.minutesLabel) of \(settings.dailyMinutesTarget.minutesLabel) — keep going 💪")
                    .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Button { withAnimation(Theme.Motion.quick) { selection = .settings } } label: {
                    Label("Change", systemImage: "pencil")
                        .font(.kCaption).foregroundStyle(Theme.Palette.accent)
                }
                .buttonStyle(.plain)
                .help("Change your daily goal in Settings")
            }
        }
    }

    private var focusStatusCard: some View {
        Button {
            withAnimation(Theme.Motion.quick) { selection = .focus }
        } label: {
            KCard {
                HStack(spacing: Theme.Spacing.lg) {
                    ZStack {
                        ProgressRing(progress: focusTimer.progress, lineWidth: 6,
                                     tint: focusTimer.isBreak ? Theme.Palette.success : Color(hex: focusTimer.subjectColorHex))
                            .frame(width: 46, height: 46)
                        Image(systemName: focusTimer.isBreak ? "cup.and.saucer.fill" : "timer")
                            .font(.system(size: 14))
                            .foregroundStyle(focusTimer.isBreak ? Theme.Palette.success : Theme.Palette.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(focusTimer.isBreak ? Theme.Palette.success : Theme.Palette.accent)
                                .frame(width: 7, height: 7)
                            Text(focusTimer.isBreak
                                 ? "On a break ☕️"
                                 : "Focusing" + (focusTimer.subjectName.map { " · \($0)" } ?? ""))
                                .font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                        }
                        Text(focusTimer.phase == .paused ? "Paused — tap to resume" : "Tap to open the timer")
                            .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Text(focusTimer.remainingText)
                        .font(.kNumber(22, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nextBlockCard: some View {
        Group {
            if let occ = nextOccurrence {
                KCard(hoverable: true) {
                    HStack(spacing: Theme.Spacing.lg) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: occ.colorHex)).frame(width: 5, height: 52)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(occ.end > .now ? "Up next" : "Earlier today")
                                .font(.kCaption).foregroundStyle(Theme.Palette.accent)
                            HStack(spacing: 6) {
                                if let subject = occ.subject {
                                    Image(systemName: subject.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: occ.colorHex))
                                }
                                Text(occ.title).font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
                            }
                            Text("\(occ.start.formatted(date: .omitted, time: .shortened)) – \(occ.end.formatted(date: .omitted, time: .shortened))")
                                .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        KPrimaryButton(title: "Start focus", icon: "play.fill") { startFocus(for: occ) }
                    }
                }
            }
        }
    }

    private func startFocus(for occ: EventOccurrence) {
        focusTimer.start(minutes: settings.focusMinutes,
                         subjectName: occ.subject?.name ?? occ.title,
                         colorHex: occ.colorHex,
                         eventID: occ.event.id)
        withAnimation(Theme.Motion.quick) { selection = .focus }
    }
}

private struct TimelineRow: View {
    let occurrence: EventOccurrence
    let onStart: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(spacing: 2) {
                Text(occurrence.start.formatted(date: .omitted, time: .shortened))
                    .font(.kNumber(12)).foregroundStyle(Theme.Palette.textPrimary)
                Text(occurrence.end.formatted(date: .omitted, time: .shortened))
                    .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(width: 64)

            RoundedRectangle(cornerRadius: 3).fill(Color(hex: occurrence.colorHex)).frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.title).font(.kBody.weight(.medium)).foregroundStyle(Theme.Palette.textPrimary)
                if let subject = occurrence.subject {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: subject.icon).font(.system(size: 10))
                            .foregroundStyle(Color(hex: subject.colorHex))
                        Text(subject.name).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            Spacer()
            if occurrence.wasSkipped {
                Text("skipped").font(.kCaption).foregroundStyle(Theme.Palette.warning)
                    .padding(.horizontal, Theme.Spacing.sm).padding(.vertical, 3)
                    .background(Theme.Palette.warning.opacity(0.14)).clipShape(Capsule())
            } else if occurrence.isCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.success)
            } else if hovering {
                Button(action: onStart) {
                    Image(systemName: "play.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.Palette.accent)
                }.buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .background(hovering ? Theme.Palette.surfaceAlt : Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).strokeBorder(Theme.Palette.border, lineWidth: 1))
        .onHover { hovering = $0 }
    }
}

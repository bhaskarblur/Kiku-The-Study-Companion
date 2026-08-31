import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Query private var sessions: [StudySession]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @State private var range = 7
    @State private var recapText: String?
    @State private var recapLoading = false
    @State private var recapError: String?

    private var daily: [(date: Date, minutes: Int)] {
        StudyStats.dailyMinutes(sessions, days: range)
    }
    private var weekMinutes: Int { StudyStats.minutesThisWeek(sessions) }
    private var weekSessions: Int { StudyStats.sessionsThisWeek(sessions) }
    private var streak: Int { StudyStats.currentStreak(sessions) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack {
                    Text("Your progress").font(.kLargeTitle).foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    KSegmentedControl(options: [(7, "7 days"), (30, "30 days")], selection: $range)
                }

                weeklyRecapCard

                HStack(spacing: Theme.Spacing.md) {
                    goalRing(title: "Weekly minutes", value: weekMinutes,
                             target: settings.weeklyMinutesTarget, tint: Theme.Palette.accent, unit: "m")
                    metricCard(icon: "flame.fill", value: "\(streak)", label: "Current streak", tint: Theme.Palette.warning)
                    metricCard(icon: "checkmark.seal.fill", value: "\(weekSessions)", label: "Sessions this week", tint: Theme.Palette.success)
                }

                if sessions.isEmpty {
                    KCard {
                        EmptyState(emoji: "📊", message: "No sessions yet.\nFinish a focus session and your stats bloom here.")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    minutesChart
                    subjectBreakdown
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var minutesChart: some View {
        KCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Minutes per day").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                Chart(daily, id: \.date) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(Theme.Palette.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }

    private var subjectBreakdown: some View {
        let totals: [(subject: Subject, minutes: Int)] = subjects.compactMap { s in
            let m = sessions.filter { $0.subject?.id == s.id }.reduce(0) { $0 + $1.focusMinutes }
            return m > 0 ? (s, m) : nil
        }.sorted { $0.minutes > $1.minutes }
        let maxMinutes = totals.map(\.minutes).max() ?? 1

        return Group {
            if !totals.isEmpty {
                KCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("By subject").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                        ForEach(totals, id: \.subject.id) { item in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                HStack {
                                    SubjectTag(name: item.subject.name, colorHex: item.subject.colorHex)
                                    Spacer()
                                    Text(item.minutes.minutesLabel).font(.kCaption)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.Palette.surfaceAlt)
                                        Capsule().fill(Color(hex: item.subject.colorHex))
                                            .frame(width: geo.size.width * CGFloat(item.minutes) / CGFloat(maxMinutes))
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private func goalRing(title: String, value: Int, target: Int, tint: Color, unit: String) -> some View {
        let progress = min(1, Double(value) / Double(max(1, target)))
        return KCard {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 9, tint: tint).frame(width: 64, height: 64)
                    Text("\(Int(progress * 100))%").font(.kNumber(13)).foregroundStyle(Theme.Palette.textPrimary)
                }
                Text("\(value)/\(target)\(unit)").font(.kNumber(14)).foregroundStyle(Theme.Palette.textPrimary)
                Text(title).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func metricCard(icon: String, value: String, label: String, tint: Color) -> some View {
        KCard {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(tint)
                Text(value).font(.kNumber(22, weight: .bold)).foregroundStyle(Theme.Palette.textPrimary)
                Text(label).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var weeklyRecapCard: some View {
        KCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("Weekly recap", systemImage: "sparkles")
                        .font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    if recapLoading {
                        HStack(spacing: Theme.Spacing.xs) {
                            ProgressView().controlSize(.small)
                            Text("Writing…").font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                        }
                    } else {
                        Button { generateRecap() } label: {
                            Label(recapText == nil ? "Write my recap" : "Rewrite",
                                  systemImage: recapText == nil ? "wand.and.stars" : "arrow.triangle.2.circlepath")
                                .font(.kBody.weight(.semibold)).foregroundStyle(Theme.Palette.accent)
                        }.buttonStyle(.plain)
                    }
                }

                // Concrete "this week" numbers — always accurate, at a glance.
                weekStatsRow

                if let recapText {
                    Text(styledRecap(recapText))
                        .font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let recapError {
                    Label(recapError, systemImage: "exclamationmark.bubble")
                        .font(.kBody).foregroundStyle(Theme.Palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tap “Write my recap” for a warm little review of your week — your wins, where to grow, and tiny goals for next week 💛")
                        .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weekStatsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            recapPill("📅", "\(daysStudiedThisWeek)/7", "days")
            recapPill("⏳", weekMinutes.minutesLabel, "focus")
            recapPill("✅", "\(weekSessions)", "sessions")
            recapPill("🔥", "\(streak)", "streak")
        }
    }

    private func recapPill(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(emoji).font(.system(size: 15))
            Text(value).font(.kNumber(14)).foregroundStyle(Theme.Palette.textPrimary)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var daysStudiedThisWeek: Int {
        let cal = Calendar.current
        guard let week = cal.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return Set(sessions.filter { week.contains($0.startedAt) }
            .map { cal.startOfDay(for: $0.startedAt) }).count
    }

    /// Renders the AI recap as markdown (so **section titles** bold and newlines are kept).
    private func styledRecap(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func generateRecap() {
        recapError = nil
        recapLoading = true
        let prompt = WeeklyRecap.buildPrompt(sessions: sessions, subjects: subjects,
                                             dailyTarget: settings.dailyMinutesTarget)
        let service = GeminiService(apiKey: settings.geminiAPIKey)
        Task {
            do {
                let text = try await service.generate(prompt: prompt)
                await MainActor.run {
                    recapText = text
                    recapLoading = false
                }
            } catch {
                await MainActor.run {
                    recapError = error.localizedDescription
                    recapLoading = false
                }
            }
        }
    }
}

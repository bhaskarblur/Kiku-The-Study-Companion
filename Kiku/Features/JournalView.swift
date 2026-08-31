import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \StudySession.startedAt, order: .reverse) private var sessions: [StudySession]
    @State private var editingSession: StudySession?

    private var grouped: [(day: Date, items: [StudySession])] {
        let dict = Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.startedAt > $1.startedAt }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Journal").font(.kLargeTitle).foregroundStyle(Theme.Palette.textPrimary)

                if sessions.isEmpty {
                    KCard {
                        EmptyState(emoji: "📖", message: "Your study diary is empty.\nEvery finished session lands here — a record to be proud of.")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(grouped, id: \.day) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Text(dayLabel(group.day)).font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                                Spacer()
                                Text("\(group.items.reduce(0) { $0 + $1.focusMinutes }.minutesLabel)")
                                    .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                            }
                            ForEach(group.items) { session in
                                Button { editingSession = session } label: { sessionCard(session) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editingSession) { SessionEditorSheet(session: $0) }
    }

    private func sessionCard(_ session: StudySession) -> some View {
        let color = session.subject?.colorHex ?? Theme.subjectColors[0]
        return KCard(padding: Theme.Spacing.md, hoverable: true) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Subject color + icon badge (matching the dashboard/calendar style).
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: color).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: session.subject?.icon ?? "book.closed.fill")
                        .font(.system(size: 14)).foregroundStyle(Color(hex: color))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle().fill(Color(hex: color)).frame(width: 8, height: 8)
                            Text(session.subject?.name ?? "Study")
                                .font(.kBody.weight(.semibold)).foregroundStyle(Theme.Palette.textPrimary)
                        }
                        Spacer()
                        Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    }

                    if !session.note.isEmpty {
                        Text(session.note).font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                    }

                    HStack(spacing: Theme.Spacing.md) {
                        Label(session.focusMinutes.minutesLabel, systemImage: "clock")
                            .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                        if let mood = session.moodRating {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text("Your experience:").font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                                Text(["😞","😕","🙂","😊","🤩"][max(0, min(4, mood - 1))]).font(.system(size: 15))
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }
}

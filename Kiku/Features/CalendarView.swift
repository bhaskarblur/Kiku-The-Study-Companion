import SwiftUI
import SwiftData

enum CalendarMode: String, CaseIterable { case day, week, agenda }

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsStore
    @Query(sort: \StudyEvent.start) private var events: [StudyEvent]

    @State private var mode: CalendarMode = .week
    @State private var anchor: Date = .now
    @State private var editing: StudyEvent?
    @State private var creatingAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Theme.Palette.border)
            Group {
                switch mode {
                case .day:
                    DayGrid(date: anchor,
                            occurrences: RecurrenceEngine.occurrences(of: events, on: anchor),
                            onCreate: create, onEdit: { editing = $0 }, onMove: move)
                case .week:
                    WeekGrid(anchor: anchor, events: events, onCreate: create, onEdit: { editing = $0 }, onMove: move)
                case .agenda:
                    AgendaList(occurrences: upcoming, onEdit: { editing = $0 })
                }
            }
        }
        .background(Theme.Palette.bg)
        .sheet(item: $editing) { EventEditorSheet(event: $0) }
        .sheet(item: Binding(get: { creatingAt.map { CreateDate(date: $0) } },
                             set: { creatingAt = $0?.date })) { wrapper in
            EventEditorSheet(defaultStart: wrapper.date)
        }
    }

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Text(title).font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
            HStack(spacing: 2) {
                iconButton("chevron.left") { shift(-1) }
                Button("Today") { anchor = .now }
                    .buttonStyle(.plain).font(.kBody).foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                iconButton("chevron.right") { shift(1) }
            }
            Spacer()
            KSegmentedControl(options: [(.day, "Day"), (.week, "Week"), (.agenda, "Agenda")], selection: $mode)
            KPrimaryButton(title: "New", icon: "plus") { creatingAt = defaultCreateDate() }
        }
        .padding(Theme.Spacing.lg)
    }

    private func iconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(Theme.Palette.textSecondary)
                .background(Theme.Palette.surfaceAlt).clipShape(Circle())
        }.buttonStyle(.plain)
    }

    private var title: String {
        switch mode {
        case .day: return anchor.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .week:
            let week = Calendar.current.dateInterval(of: .weekOfYear, for: anchor)
            let start = week?.start ?? anchor
            return start.formatted(.dateTime.day().month(.wide).year())
        case .agenda: return "Upcoming"
        }
    }

    private var upcoming: [EventOccurrence] {
        let now = Date.now
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return RecurrenceEngine.occurrences(of: events, in: DateInterval(start: now, end: end))
            .filter { $0.end > now }
    }

    private func shift(_ dir: Int) {
        let comp: Calendar.Component = mode == .day ? .day : .weekOfYear
        anchor = Calendar.current.date(byAdding: comp, value: dir, to: anchor) ?? anchor
    }

    private func create(at date: Date) { creatingAt = date }

    /// Shifts an event (and its series, if recurring) by a number of minutes after a drag.
    private func move(_ event: StudyEvent, byMinutes minutes: Int) {
        guard minutes != 0 else { return }
        let duration = event.end.timeIntervalSince(event.start)
        let newStart = event.start.addingTimeInterval(TimeInterval(minutes * 60))
        event.start = newStart
        event.end = newStart.addingTimeInterval(duration)
        NotificationManager.shared.schedule(for: event,
            interval: settings.presenceChecksEnabled ? settings.presenceIntervalMinutes : 0)
        if settings.calendarSyncEnabled {
            let cid = settings.calendarSyncID.isEmpty ? nil : settings.calendarSyncID
            if let id = CalendarSyncService.shared.mirror(event, toCalendarID: cid) { event.ekIdentifier = id }
        }
    }

    private func defaultCreateDate() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: max(9, cal.component(.hour, from: .now)), minute: 0, second: 0, of: anchor) ?? anchor
    }
}

private struct CreateDate: Identifiable { let id = UUID(); let date: Date }

// MARK: - Hour grid shared geometry

private enum Grid {
    static let hourHeight: CGFloat = 52
    static let startHour = 6
    static let endHour = 24

    static func y(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return CGFloat(h - startHour) * hourHeight + CGFloat(m) / 60 * hourHeight
    }

    static var hours: [Int] { Array(startHour...endHour) }
    static var totalHeight: CGFloat { CGFloat(endHour - startHour) * hourHeight }
}

// MARK: - Day grid

private struct DayGrid: View {
    let date: Date
    let occurrences: [EventOccurrence]
    let onCreate: (Date) -> Void
    let onEdit: (StudyEvent) -> Void
    let onMove: (StudyEvent, Int) -> Void

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                hoursColumn
                ZStack(alignment: .topLeading) {
                    gridLines
                    ForEach(occurrences) { occ in
                        EventBlock(occurrence: occ, onMoved: { onMove(occ.event, $0) }) { onEdit(occ.event) }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .offset(y: Grid.y(for: occ.start))
                            .frame(height: blockHeight(occ), alignment: .top)
                    }
                    if Calendar.current.isDateInToday(date) { nowLine }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var hoursColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Grid.hours, id: \.self) { h in
                Text(hourLabel(h)).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    .frame(height: Grid.hourHeight, alignment: .top)
            }
        }
        .frame(width: 52)
        .padding(.trailing, Theme.Spacing.sm)
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(Grid.hours, id: \.self) { h in
                HourSlot { onCreate(dateAt(hour: h)) }
            }
        }
    }

    private var nowLine: some View {
        Rectangle().fill(Theme.Palette.warning).frame(height: 2)
            .offset(y: Grid.y(for: .now))
            .frame(maxWidth: .infinity)
    }

    private func blockHeight(_ o: EventOccurrence) -> CGFloat {
        max(24, CGFloat(o.durationMinutes) / 60 * Grid.hourHeight)
    }

    private func hourLabel(_ h: Int) -> String {
        let d = Calendar.current.date(bySettingHour: h % 24, minute: 0, second: 0, of: .now) ?? .now
        return d.formatted(.dateTime.hour())
    }

    private func dateAt(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour % 24, minute: 0, second: 0, of: date) ?? date
    }
}

// MARK: - Week grid

private struct WeekGrid: View {
    let anchor: Date
    let events: [StudyEvent]
    let onCreate: (Date) -> Void
    let onEdit: (StudyEvent) -> Void
    let onMove: (StudyEvent, Int) -> Void

    private var days: [Date] {
        let cal = Calendar.current
        guard let week = cal.dateInterval(of: .weekOfYear, for: anchor) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: week.start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerRow
                HStack(alignment: .top, spacing: 0) {
                    hoursColumn
                    ForEach(days, id: \.self) { day in
                        dayColumn(day)
                        if day != days.last { Divider().overlay(Theme.Palette.border) }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 52)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.kCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(day.formatted(.dateTime.day())).font(.kNumber(15))
                        .foregroundStyle(isToday ? .white : Theme.Palette.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(isToday ? Theme.Palette.accent : .clear)
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var hoursColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Grid.hours, id: \.self) { h in
                Text(hourLabel(h)).font(.system(size: 10))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(height: Grid.hourHeight, alignment: .top)
            }
        }
        .frame(width: 52)
        .padding(.trailing, Theme.Spacing.xs)
    }

    private func dayColumn(_ day: Date) -> some View {
        let dayOccurrences = RecurrenceEngine.occurrences(of: events, on: day)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Grid.hours, id: \.self) { h in
                    HourSlot(compact: true) { onCreate(dateAt(hour: h, day: day)) }
                }
            }
            ForEach(dayOccurrences) { occ in
                EventBlock(occurrence: occ, compact: true, onMoved: { onMove(occ.event, $0) }) { onEdit(occ.event) }
                    .padding(.horizontal, 3)
                    .offset(y: Grid.y(for: occ.start))
                    .frame(height: max(20, CGFloat(occ.durationMinutes) / 60 * Grid.hourHeight), alignment: .top)
            }
            if Calendar.current.isDateInToday(day) {
                Rectangle().fill(Theme.Palette.warning).frame(height: 2).offset(y: Grid.y(for: .now))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func hourLabel(_ h: Int) -> String {
        let d = Calendar.current.date(bySettingHour: h % 24, minute: 0, second: 0, of: .now) ?? .now
        return d.formatted(.dateTime.hour())
    }

    private func dateAt(hour: Int, day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour % 24, minute: 0, second: 0, of: day) ?? day
    }
}

// MARK: - Agenda list

private struct AgendaList: View {
    let occurrences: [EventOccurrence]
    let onEdit: (StudyEvent) -> Void

    private var grouped: [(day: Date, items: [EventOccurrence])] {
        let dict = Dictionary(grouping: occurrences) { Calendar.current.startOfDay(for: $0.start) }
        return dict.keys.sorted().map { ($0, dict[$0]!.sorted { $0.start < $1.start }) }
    }

    var body: some View {
        if occurrences.isEmpty {
            EmptyState(emoji: "🗓️", message: "Nothing scheduled ahead.\nAdd a study block to fill your week.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(grouped, id: \.day) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(dayLabel(group.day)).font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                            ForEach(group.items) { occ in
                                Button { onEdit(occ.event) } label: { agendaRow(occ) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func agendaRow(_ occ: EventOccurrence) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: occ.colorHex)).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(occ.title).font(.kBody.weight(.medium)).foregroundStyle(Theme.Palette.textPrimary)
                Text("\(occ.start.formatted(date: .omitted, time: .shortened)) – \(occ.end.formatted(date: .omitted, time: .shortened))")
                    .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            if occ.recurrence != .none {
                Image(systemName: "repeat").font(.system(size: 11)).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).strokeBorder(Theme.Palette.border, lineWidth: 1))
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }
}

// MARK: - Event block

private struct EventBlock: View {
    let occurrence: EventOccurrence
    var compact: Bool = false
    var onMoved: ((Int) -> Void)? = nil
    let onTap: () -> Void
    @GestureState private var dragOffset: CGFloat = 0

    private var timeRange: String {
        "\(occurrence.start.formatted(date: .omitted, time: .shortened)) – \(occurrence.end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    if let subject = occurrence.subject {
                        Image(systemName: subject.icon)
                            .font(.system(size: compact ? 9 : 11))
                            .foregroundStyle(Color(hex: occurrence.colorHex))
                    }
                    Text(occurrence.title).font(.system(size: compact ? 11 : 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                }
                Text(timeRange)
                    .font(.system(size: compact ? 9 : 11))
                    .foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
                if !occurrence.notes.isEmpty {
                    Text(occurrence.notes)
                        .font(.system(size: compact ? 9 : 11))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(compact ? 1 : 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, compact ? 3 : Theme.Spacing.xs)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(hex: occurrence.colorHex).opacity(0.20))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: occurrence.colorHex)).frame(width: 3)
            }
            .overlay(alignment: .topTrailing) {
                if occurrence.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(Theme.Palette.success)
                        .padding(3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .offset(y: dragOffset)
        .zIndex(dragOffset == 0 ? 0 : 1)
        .simultaneousGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragOffset) { value, state, _ in
                guard onMoved != nil else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard let onMoved else { return }
                // Snap the vertical drag to 15-minute steps.
                let minutes = Int((value.translation.height / Grid.hourHeight * 60 / 15).rounded()) * 15
                if minutes != 0 { onMoved(minutes) }
            }
    }
}

// MARK: - Hour slot (hover to reveal add affordance)

private struct HourSlot: View {
    var compact: Bool = false
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.Palette.border.opacity(0.6)).frame(height: 1)
            Spacer(minLength: 0)
        }
        .frame(height: Grid.hourHeight)
        .frame(maxWidth: .infinity)
        .background(hovering ? Theme.Palette.accent.opacity(0.06) : .clear)
        .overlay(alignment: .center) {
            if hovering {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: compact ? 13 : 16))
                    .foregroundStyle(Theme.Palette.accent.opacity(0.75))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { onTap() }
        .help("Add a study block here")
    }
}

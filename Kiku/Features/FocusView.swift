import SwiftUI
import SwiftData

struct FocusView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var focusTimer: FocusTimer
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Query(sort: \StudyEvent.start) private var events: [StudyEvent]

    @State private var selectedSubject: Subject?
    /// The calendar occurrence we've already auto-applied defaults from, so we don't
    /// keep overwriting manual adjustments on every re-check.
    @State private var appliedOccurrenceID: String?
    private let smartSuggestionTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var ringColor: Color {
        if focusTimer.isBreak { return Theme.Palette.success }
        return focusTimer.isActive ? Color(hex: focusTimer.subjectColorHex) : Theme.Palette.accent
    }

    /// The calendar block covering right now, if any.
    private var currentOccurrence: EventOccurrence? {
        RecurrenceEngine.occurrences(of: events, on: .now).first { $0.start <= .now && $0.end > .now }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            if focusTimer.isBreak {
                Text("ON A BREAK ☕️")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.success)
                    .tracking(1.5)
            } else if let name = focusTimer.subjectName, focusTimer.phase != .idle {
                Text(name.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .tracking(1.5)
            } else {
                Text("READY TO FOCUS AND START WORKING ON THE TASK")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .tracking(1.5)
            }

            ZStack {
                ProgressRing(progress: focusTimer.phase == .idle ? 0 : focusTimer.progress,
                             lineWidth: 14, tint: ringColor)
                    .frame(width: 260, height: 260)
                VStack(spacing: Theme.Spacing.xs) {
                    Text(focusTimer.phase == .idle ? "\(settings.focusMinutes):00" : focusTimer.remainingText)
                        .font(.kNumber(56, weight: .bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .monospacedDigit()
                    Text(phaseLabel).font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .animation(Theme.Motion.spring, value: focusTimer.phase)

            if focusTimer.phase == .idle { focusMinutesStepper }

            if focusTimer.phase == .idle, let occ = currentOccurrence, occ.id == appliedOccurrenceID {
                Label("Auto-set from “\(occ.title)” on your calendar", systemImage: "calendar")
                    .font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }

            controls

            if focusTimer.phase == .idle { subjectPicker }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
        .onAppear {
            if selectedSubject == nil { selectedSubject = subjects.first }
            applySmartDefaultsIfNeeded()
        }
        .onReceive(smartSuggestionTicker) { _ in applySmartDefaultsIfNeeded() }
    }

    /// Prefills the focus length and subject from the calendar block running right now —
    /// only once per occurrence, so it never clobbers a manual tweak mid-block.
    private func applySmartDefaultsIfNeeded() {
        guard focusTimer.phase == .idle, let occ = currentOccurrence, occ.id != appliedOccurrenceID else { return }
        if occ.durationMinutes > 0 {
            settings.focusMinutes = min(Self.focusMinutesRange.upperBound,
                                        max(Self.focusMinutesRange.lowerBound, occ.durationMinutes))
        }
        if let subject = occ.subject { selectedSubject = subject }
        appliedOccurrenceID = occ.id
    }

    private static let focusMinutesRange = 5...180
    private static let focusMinutesStep = 5

    private var focusMinutesStepper: some View {
        HStack(spacing: Theme.Spacing.lg) {
            stepperButton(icon: "minus") { adjustFocusMinutes(by: -Self.focusMinutesStep) }
                .disabled(settings.focusMinutes <= Self.focusMinutesRange.lowerBound)
            VStack(spacing: 1) {
                Text("\(settings.focusMinutes) min").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                Text("Focus length").font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(minWidth: 96)
            stepperButton(icon: "plus") { adjustFocusMinutes(by: Self.focusMinutesStep) }
                .disabled(settings.focusMinutes >= Self.focusMinutesRange.upperBound)
        }
    }

    private func stepperButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.Palette.surfaceAlt)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func adjustFocusMinutes(by delta: Int) {
        let next = settings.focusMinutes + delta
        settings.focusMinutes = min(Self.focusMinutesRange.upperBound, max(Self.focusMinutesRange.lowerBound, next))
    }

    private var phaseLabel: String {
        if focusTimer.isBreak {
            switch focusTimer.phase {
            case .paused: return "Break paused"
            default: return "Relax and recharge ☕️"
            }
        }
        switch focusTimer.phase {
        case .idle: return "Tap start when you're ready 🌿"
        case .running: return "Stay with it — you're doing great"
        case .paused: return "Paused"
        case .finished: return "Done! 🎉"
        }
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            if focusTimer.isBreak {
                switch focusTimer.phase {
                case .running:
                    KSecondaryButton(title: "Pause", icon: "pause.fill") { focusTimer.pause() }
                    KPrimaryButton(title: "Skip break", icon: "forward.fill") { focusTimer.finishNow() }
                case .paused:
                    KPrimaryButton(title: "Resume", icon: "play.fill") { focusTimer.resume() }
                    KSecondaryButton(title: "Skip break", icon: "forward.fill") { focusTimer.finishNow() }
                default:
                    EmptyView()
                }
            } else {
                switch focusTimer.phase {
                case .idle:
                    KPrimaryButton(title: "Start focus", icon: "play.fill") {
                        let linkedOccurrence = currentOccurrence?.id == appliedOccurrenceID ? currentOccurrence : nil
                        focusTimer.start(minutes: settings.focusMinutes,
                                         subjectName: selectedSubject?.name,
                                         colorHex: selectedSubject?.colorHex ?? Theme.subjectColors[0],
                                         eventID: linkedOccurrence?.event.id)
                    }
                case .running:
                    KSecondaryButton(title: "Pause", icon: "pause.fill") { focusTimer.pause() }
                    KSecondaryButton(title: "Stop", icon: "stop.fill") { focusTimer.stop() }
                case .paused:
                    KPrimaryButton(title: "Resume", icon: "play.fill") { focusTimer.resume() }
                    KSecondaryButton(title: "Finish", icon: "checkmark") { focusTimer.finishNow() }
                case .finished:
                    Text("Wrapping up…").font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var subjectPicker: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("What are you studying?").font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                ForEach(subjects) { s in
                    let selected = selectedSubject?.id == s.id
                    Button { selectedSubject = s } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle().fill(Color(hex: s.colorHex)).frame(width: 8, height: 8)
                            Text(s.name).font(.kCaption)
                        }
                        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                        .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .background(selected ? Color(hex: s.colorHex).opacity(0.18) : Theme.Palette.surfaceAlt)
                        .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 640)
        }
    }
}

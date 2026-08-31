import SwiftUI
import SwiftData

struct FocusView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var focusTimer: FocusTimer
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @State private var selectedSubject: Subject?

    private var ringColor: Color {
        if focusTimer.isBreak { return Theme.Palette.success }
        return focusTimer.isActive ? Color(hex: focusTimer.subjectColorHex) : Theme.Palette.accent
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
                Text("READY TO FOCUS")
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

            controls

            if focusTimer.phase == .idle { subjectPicker }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
        .onAppear { if selectedSubject == nil { selectedSubject = subjects.first } }
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
                        focusTimer.start(minutes: settings.focusMinutes,
                                         subjectName: selectedSubject?.name,
                                         colorHex: selectedSubject?.colorHex ?? Theme.subjectColors[0])
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
            HStack(spacing: Theme.Spacing.sm) {
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
        }
    }
}

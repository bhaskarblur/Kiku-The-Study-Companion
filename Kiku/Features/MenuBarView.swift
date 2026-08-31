import SwiftUI

/// Compact focus controls shown from the menu-bar icon.
struct MenuBarView: View {
    @EnvironmentObject private var focusTimer: FocusTimer
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("🎐").font(.system(size: 18))
                Text("Kiku Focus").font(.kHeadline).foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
            }

            if focusTimer.isActive {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(focusTimer.remainingText)
                        .font(.kNumber(34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let name = focusTimer.subjectName {
                        Text(name).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                ProgressRing(progress: focusTimer.progress, lineWidth: 6,
                             tint: Color(hex: focusTimer.subjectColorHex))
                    .frame(width: 44, height: 44)

                HStack(spacing: Theme.Spacing.sm) {
                    if focusTimer.phase == .running {
                        KSecondaryButton(title: "Pause", icon: "pause.fill") { focusTimer.pause() }
                    } else {
                        KPrimaryButton(title: "Resume", icon: "play.fill") { focusTimer.resume() }
                    }
                    KSecondaryButton(title: "Stop", icon: "stop.fill") { focusTimer.stop() }
                }
            } else {
                Text("No active session.").font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                KPrimaryButton(title: "Start \(settings.focusMinutes) min focus", icon: "play.fill", fullWidth: true) {
                    focusTimer.start(minutes: settings.focusMinutes)
                }
            }

            Divider().overlay(Theme.Palette.border)
            Button("Quit Kiku") { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 240)
        .background(Theme.Palette.bg)
    }
}

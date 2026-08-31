import SwiftUI

/// A gentle in-app modal that asks "still on it?" during a study block.
/// Offers Yes, Snooze, Stop for today, and a permanent "never show again". See FRD §3.2.
struct PresenceCheckOverlay: View {
    let occurrence: EventOccurrence
    let onYes: () -> Void
    let onSnooze: () -> Void
    let onStopToday: () -> Void
    let onNever: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onSnooze() }

            VStack(spacing: Theme.Spacing.lg) {
                Text("👀")
                    .font(.system(size: 48))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(Theme.Motion.spring, value: appeared)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Still on it?").font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
                    Text("A quick check — are you focusing on \(occurrence.title)?")
                        .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    KPrimaryButton(title: "Yes, focusing ✨", icon: "checkmark", fullWidth: true) { onYes() }
                    HStack(spacing: Theme.Spacing.sm) {
                        KSecondaryButton(title: "Snooze 10 min", icon: "clock") { onSnooze() }
                        KSecondaryButton(title: "Stop for today", icon: "moon.zzz") { onStopToday() }
                    }
                }

                Button(action: onNever) {
                    Text("Don't show this again ever")
                        .font(.kCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.xxl)
            .frame(width: 420)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(Theme.Motion.spring) { appeared = true } }
    }
}

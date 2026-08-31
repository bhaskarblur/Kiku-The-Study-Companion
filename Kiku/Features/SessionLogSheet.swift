import SwiftUI
import SwiftData

/// "What did you study?" prompt shown after a focus session. See FRD §3.3.
struct SessionLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    let focusMinutes: Int
    var suggestedSubject: Subject?
    var linkedEvent: StudyEvent?

    @State private var subject: Subject?
    @State private var note = ""
    @State private var mood = 3
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Text("🎉").font(.system(size: 40)).scaleEffect(celebrate ? 1.15 : 1)
                    .animation(Theme.Motion.spring, value: celebrate)
                Text("Nice work!").font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
                Text("You focused for \(focusMinutes.minutesLabel). What did you study?")
                    .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("SUBJECT").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(subjects) { s in
                            let selected = subject?.id == s.id
                            Button { subject = s } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Circle().fill(Color(hex: s.colorHex)).frame(width: 8, height: 8)
                                    Text(s.name).font(.kCaption)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                                .background(selected ? Color(hex: s.colorHex).opacity(0.18) : Theme.Palette.surfaceAlt)
                                .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }

                Text("NOTE").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("e.g. Learned 20 new words, past tense…", text: $note, axis: .vertical)
                    .textFieldStyle(.plain).font(.kBody).lineLimit(2...4)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))

                Text("HOW DID IT FEEL?").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(1...5, id: \.self) { i in
                        Button { mood = i } label: {
                            Text(["😞","😕","🙂","😊","🤩"][i-1])
                                .font(.system(size: 24))
                                .opacity(mood == i ? 1 : 0.4)
                                .scaleEffect(mood == i ? 1.15 : 1)
                        }.buttonStyle(.plain)
                    }
                }
            }

            HStack {
                KSecondaryButton(title: "Skip") { dismiss() }
                KPrimaryButton(title: "Save session", icon: "checkmark", fullWidth: true) { save() }
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 420)
        .background(Theme.Palette.bg)
        .onAppear {
            subject = suggestedSubject ?? subjects.first
            celebrate = true
        }
    }

    private func save() {
        let session = StudySession(
            startedAt: Date().addingTimeInterval(TimeInterval(-focusMinutes * 60)),
            endedAt: .now,
            focusMinutes: focusMinutes,
            note: note,
            moodRating: mood,
            source: .pomodoro,
            subject: subject,
            event: linkedEvent
        )
        context.insert(session)
        if let linkedEvent {
            NotificationManager.shared.cancelSkipNudge(eventID: linkedEvent.id.uuidString)
        }
        dismiss()
    }
}

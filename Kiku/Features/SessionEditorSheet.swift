import SwiftUI
import SwiftData

/// Edit a logged study session from the Journal (subject, note, mood, times).
struct SessionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    let session: StudySession

    @State private var subject: Subject?
    @State private var note = ""
    @State private var mood = 3
    @State private var startedAt = Date()
    @State private var endedAt = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit session").font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(Theme.Palette.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(Theme.Spacing.xl)

            Divider().overlay(Theme.Palette.border)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    field("Subject") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(subjects) { s in
                                    let selected = subject?.id == s.id
                                    Button { subject = s } label: {
                                        HStack(spacing: Theme.Spacing.xs) {
                                            Image(systemName: s.icon).font(.system(size: 11))
                                                .foregroundStyle(Color(hex: s.colorHex))
                                            Text(s.name).font(.kCaption)
                                        }
                                        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                                        .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                                        .background(selected ? Color(hex: s.colorHex).opacity(0.18) : Theme.Palette.surfaceAlt)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(selected ? Color(hex: s.colorHex) : .clear, lineWidth: 1.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    field("Started") {
                        HStack(spacing: Theme.Spacing.sm) {
                            KDateField(date: $startedAt)
                            DatePicker("", selection: $startedAt, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact)
                        }
                    }
                    field("Ended") {
                        HStack(spacing: Theme.Spacing.sm) {
                            KDateField(date: $endedAt)
                            DatePicker("", selection: $endedAt, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact)
                        }
                    }

                    field("Note") {
                        TextEditor(text: $note)
                            .font(.kBody).frame(height: 80)
                            .padding(Theme.Spacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(Theme.Palette.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    }

                    field("Your experience") {
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
                }
                .padding(Theme.Spacing.xl)
            }

            Divider().overlay(Theme.Palette.border)

            HStack {
                Spacer()
                KSecondaryButton(title: "Cancel") { dismiss() }
                KPrimaryButton(title: "Save", icon: "checkmark") { save() }
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: 460, height: 560)
        .background(Theme.Palette.bg)
        .onAppear(perform: load)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            content()
        }
    }

    private func load() {
        subject = session.subject
        note = session.note
        mood = session.moodRating ?? 3
        startedAt = session.startedAt
        endedAt = session.endedAt
    }

    private func save() {
        session.subject = subject
        session.note = note
        session.moodRating = mood
        session.startedAt = startedAt
        session.endedAt = max(startedAt, endedAt)
        session.focusMinutes = max(1, Int(session.endedAt.timeIntervalSince(startedAt) / 60))
        dismiss()
    }
}

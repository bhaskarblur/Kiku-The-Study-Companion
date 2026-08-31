import SwiftUI
import SwiftData

struct SubjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var subject: Subject?

    @State private var name = ""
    @State private var colorHex = Theme.subjectColors[0]
    @State private var icon = "book.closed.fill"

    private let icons = ["book.closed.fill", "text.bubble.fill", "character.book.closed.fill",
                         "pencil.and.ruler.fill", "brain.head.profile", "globe.europe.africa.fill",
                         "music.note", "function", "flask.fill", "paintpalette.fill"]

    private var isEditing: Bool { subject != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text(isEditing ? "Edit subject" : "New subject")
                .font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("NAME").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Palette.textSecondary)
                    TextField("e.g. French", text: $name)
                        .textFieldStyle(.plain).font(.kBody)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Palette.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("COLOR").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Palette.textSecondary)
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Theme.subjectColors, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                                    .overlay(Circle().strokeBorder(Theme.Palette.textPrimary,
                                                                   lineWidth: colorHex == hex ? 2 : 0))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("ICON").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Palette.textSecondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: Theme.Spacing.sm) {
                        ForEach(icons, id: \.self) { name in
                            Button { icon = name } label: {
                                Image(systemName: name).font(.system(size: 16))
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(icon == name ? .white : Theme.Palette.textSecondary)
                                    .background(icon == name ? Color(hex: colorHex) : Theme.Palette.surfaceAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                KSecondaryButton(title: "Cancel") { dismiss() }
                KPrimaryButton(title: "Save", icon: "checkmark", fullWidth: true) { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 380)
        .background(Theme.Palette.bg)
        .onAppear(perform: load)
    }

    private func load() {
        if let subject {
            name = subject.name
            colorHex = subject.colorHex
            icon = subject.icon
        }
    }

    private func save() {
        if let subject {
            subject.name = name
            subject.colorHex = colorHex
            subject.icon = icon
        } else {
            context.insert(Subject(name: name, colorHex: colorHex, icon: icon))
        }
        dismiss()
    }
}

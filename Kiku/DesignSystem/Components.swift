import SwiftUI

// MARK: - Card

/// A padded rounded surface with an optional hover lift.
struct KCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.lg
    var hoverable: Bool = false
    @ViewBuilder var content: () -> Content

    @State private var hovering = false

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.10 : 0.04),
                    radius: hovering ? 14 : 8, x: 0, y: hovering ? 4 : 2)
            .offset(y: hovering ? -2 : 0)
            .animation(Theme.Motion.quick, value: hovering)
            .onHover { if hoverable { hovering = $0 } }
    }
}

// MARK: - Buttons

struct KPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.kHeadline).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundStyle(.white)
            .background(Theme.Palette.accent)
            .brightness(hovering ? 0.08 : 0)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .shadow(color: Theme.Palette.accent.opacity(hovering ? 0.35 : 0), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
    }
}

struct KSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.kHeadline).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundStyle(Theme.Palette.textPrimary)
            .background(hovering ? Theme.Palette.border : Theme.Palette.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(hovering ? Theme.Palette.accent.opacity(0.5) : Theme.Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering = $0 }
        .animation(Theme.Motion.quick, value: hovering)
    }
}

/// Scales down slightly on press for a gentle tactile feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - Friendly date field

/// A date field that shows a human-friendly label (e.g. "8 Sept, 2026") and opens
/// a calendar popover — friendlier than the compact numeric picker.
struct KDateField: View {
    @Binding var date: Date
    @State private var showPicker = false

    private var label: String {
        let day = Calendar.current.component(.day, from: date)
        let month = date.formatted(.dateTime.month(.abbreviated))
        let year = Calendar.current.component(.year, from: date)
        return "\(day) \(month), \(year)"
    }

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "calendar").font(.system(size: 12)).foregroundStyle(Theme.Palette.accent)
                Text(label).font(.kBody).foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 1)
            .background(Theme.Palette.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Theme.Palette.accent)
                .padding(Theme.Spacing.md)
                .frame(width: 300)
        }
    }
}

// MARK: - Stat chip

struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = Theme.Palette.accent

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.kNumber(16)).foregroundStyle(Theme.Palette.textPrimary)
                Text(label).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    /// 0...1
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.Palette.accent
    var track: Color = Theme.Palette.surfaceAlt

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.spring, value: progress)
        }
    }
}

// MARK: - Subject tag

struct SubjectTag: View {
    let name: String
    let colorHex: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle().fill(Color(hex: colorHex)).frame(width: 8, height: 8)
            Text(name).font(.kCaption).foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let emoji: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(emoji).font(.system(size: 44))
            Text(message)
                .font(.kBody)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                KPrimaryButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: 320)
        .padding(Theme.Spacing.xxl)
    }
}

// MARK: - Segmented control

struct KSegmentedControl<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(Theme.Motion.quick) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.kBody.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs + 2)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Theme.Radius.control - 2, style: .continuous)
                                    .fill(Theme.Palette.surface)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.Palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

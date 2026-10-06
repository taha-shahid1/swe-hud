import SwiftUI

struct ThreadRowView: View {
    let thread: ThreadItem
    let isSelected: Bool
    let isEditing: Bool
    var onCommitNextStep: (String) -> Void

    @State private var draft: String = ""
    @State private var hovering: Bool = false
    @FocusState private var fieldFocused: Bool

    private var ageText: String? {
        guard thread.status != .done else { return nil }
        let idle = Date().timeIntervalSince(thread.updatedAt)
        guard idle >= 30 * 60 else { return nil }
        let hours = Int(idle / 3600)
        if hours >= 24 { return "quiet \(hours / 24)d" }
        if hours >= 1 { return "quiet \(hours)h" }
        return "quiet \(max(1, Int(idle / 60)))m"
    }

    /// The next step, or — only on the selected row — a hint for adding
    /// one. Unselected rows without a step stay one line instead of
    /// repeating filler text.
    private var subtitle: (text: String, isHint: Bool)? {
        if let step = thread.nextStep { return (step, false) }
        return isSelected ? ("↩ add a next step", true) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Baseline, so the dot and key stay on the title's first line when it wraps.
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                StatusDot(status: thread.status)

                if !thread.key.isEmpty {
                    Text(thread.key)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        )
                }

                Text(thread.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(thread.status == .done ? .tertiary : .primary)
                    .strikethrough(thread.status == .done)
                    .lineLimit(isSelected ? nil : 1)

                Spacer(minLength: 0)
            }

            if isEditing {
                // Wraps as you type instead of scrolling sideways; Return still submits.
                TextField("Next step…", text: $draft, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .padding(.leading, 24)
                    .focused($fieldFocused)
                    .onAppear {
                        draft = thread.nextStep ?? ""
                        fieldFocused = true
                    }
                    .onSubmit {
                        onCommitNextStep(draft)
                    }
            } else if subtitle != nil || ageText != nil {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    if let subtitle {
                        Text(subtitle.text)
                            .font(.system(size: 12))
                            .foregroundStyle(subtitle.isHint ? .tertiary : .secondary)
                            .lineLimit(isSelected ? nil : 1)
                    }
                    Spacer(minLength: 0)
                    if let ageText {
                        HStack(spacing: 3) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 9))
                            Text(ageText)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.09 : (hovering ? 0.05 : 0)))
        )
        .opacity(thread.status == .done ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

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
        let idle = Date().timeIntervalSince(thread.updatedAt)
        guard idle >= 30 * 60 else { return nil }
        let hours = Int(idle / 3600)
        if hours >= 24 { return "quiet \(hours / 24)d" }
        if hours >= 1 { return "quiet \(hours)h" }
        return "quiet \(max(1, Int(idle / 60)))m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                StatusDot(status: thread.status)

                if !thread.key.isEmpty {
                    Text(thread.key)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        )
                }

                Text(thread.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(thread.status == .done ? .tertiary : .primary)
                    .strikethrough(thread.status == .done)
                    .lineLimit(1)

                Spacer(minLength: Theme.Spacing.sm)

                if let ageText {
                    HStack(spacing: 3) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 9))
                        Text(ageText)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            if isEditing {
                TextField("Next step…", text: $draft)
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
            } else {
                Text(thread.nextStep ?? thread.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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

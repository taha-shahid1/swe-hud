import SwiftUI

/// The always-visible quick-capture bar at the top of the left panel.
/// The quick-capture hotkey opens the panel (if needed) and focuses this
/// field directly, so typing + Enter creates a thread with no clicking.
struct CaptureField: View {
    let appState: HUDAppState
    var onCommit: (String) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(focused ? Theme.accent : Color.secondary)

            TextField("Capture a thread — ⌥N", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Color.primary.opacity(focused ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.accent.opacity(focused ? 0.35 : 0), lineWidth: 1)
        )
        .focused($focused)
        .onSubmit {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onCommit(trimmed)
            text = ""
        }
        .onChange(of: appState.captureFocusTrigger) { _, _ in
            focused = true
        }
        .onChange(of: focused) { _, newValue in
            appState.isCaptureFocused = newValue
        }
    }
}

import SwiftUI

struct DurationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var secondsText: String

    let title: String
    let onSave: (Int) -> Void

    init(title: String, seconds: Int, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.onSave = onSave
        _secondsText = State(initialValue: String(seconds))
    }

    private var seconds: Int? {
        guard let value = Int(secondsText), (1...86_399).contains(value) else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TempoPalette.ink)
                Text("Enter the duration in whole seconds")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
            }

            HStack(spacing: 10) {
                TextField("60", text: $secondsText)
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($isInputFocused)
                    .accessibilityLabel("Duration in seconds")
                Text("SEC")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(TempoPalette.muted)
            }
            .padding(.horizontal, 18)
            .frame(height: 68)
            .background(TempoPalette.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(TempoPalette.line, lineWidth: 1))

            Text("Use any whole number from 1 to 86,399.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TempoPalette.muted)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(TempoPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(TempoPalette.softGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("Set time") {
                    guard let seconds else { return }
                    onSave(seconds)
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(TempoPalette.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(seconds == nil)
                .opacity(seconds == nil ? 0.45 : 1)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .onAppear { isInputFocused = true }
    }
}

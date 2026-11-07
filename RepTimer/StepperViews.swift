import SwiftUI

struct DurationStepper: View {
    let title: String
    let subtitle: String
    let value: Int
    let tint: Color
    let format: (Int) -> String
    let decrement: () -> Void
    let increment: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(TempoPalette.ink)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
            }
            Spacer(minLength: 6)
            StepperButton(symbol: "minus", action: decrement)
            Button(action: edit) {
                Text(format(value))
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(TempoPalette.ink)
                    .frame(minWidth: 54, alignment: .center)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(title.lowercased()) time, currently \(format(value))")
            StepperButton(symbol: "plus", action: increment)
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
    }
}

struct RoundStepper: View {
    let value: Int
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(TempoPalette.lime).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text("ROUNDS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(TempoPalette.ink)
                Text("Repeat the intervals")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
            }
            Spacer(minLength: 6)
            StepperButton(symbol: "minus", action: decrement)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(TempoPalette.ink)
                .frame(minWidth: 54)
                .contentTransition(.numericText())
            StepperButton(symbol: "plus", action: increment)
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
    }
}

struct StepperButton: View {
    let symbol: String
    let action: () -> Void
    @State private var tapCount = 0

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                action()
            }
            tapCount += 1
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TempoPalette.ink)
                .frame(width: 44, height: 44)
                .tempoGlass(in: Circle(), tint: .white.opacity(0.3))
                .contentShape(Circle())
        }
        .buttonStyle(StepperPressStyle())
        .sensoryFeedback(.selection, trigger: tapCount)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}

struct StepperPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

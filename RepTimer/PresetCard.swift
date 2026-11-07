import SwiftUI

struct PresetCard: View {
    let preset: TimerPreset
    let isSelected: Bool
    let action: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    private var detailText: String {
        var options: [String] = []
        if preset.preparationEnabled { options.append("\(preset.preparationSeconds)s prep") }
        if preset.cooldownEnabled { options.append("\(preset.cooldownSeconds)s cooldown") }
        return "\(preset.rounds) rounds" + options.map { " · \($0)" }.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: preset.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? TempoPalette.accentInk : TempoPalette.ink)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? TempoPalette.lime : TempoPalette.softGreen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer(minLength: 0)
                Menu {
                    Button("Edit preset", systemImage: "pencil", action: edit)
                    Button("Delete preset", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TempoPalette.muted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Manage \(preset.name) preset")
            }
            Button(action: action) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TempoPalette.ink)
                        .lineLimit(1)
                    Text(detailText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(TempoPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("\(preset.work)s / \(preset.rest)s")
                        .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(TempoPalette.ink)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(preset.name) preset, \(preset.work) seconds work and \(preset.rest) seconds rest")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 118, alignment: .topLeading)
        .padding(12)
        .tempoGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: isSelected ? TempoPalette.lime.opacity(0.22) : nil
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? TempoPalette.forest.opacity(0.65) : .white.opacity(0.75), lineWidth: isSelected ? 1.4 : 1))
    }
}

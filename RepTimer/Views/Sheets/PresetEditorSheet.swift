import SwiftUI
import UIKit

struct PresetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var workText: String
    @State private var restText: String
    @State private var roundsText: String
    @State private var preparationText: String
    @State private var preparationEnabled: Bool
    @State private var cooldownText: String
    @State private var cooldownEnabled: Bool
    @State private var selectedSymbol: String

    private let symbols = [
        "timer", "dumbbell.fill", "bolt.fill", "figure.run",
        "figure.strengthtraining.traditional", "flame.fill", "heart.fill", "figure.cooldown"
    ]

    let preset: TimerPreset
    let isNew: Bool
    let onSave: (TimerPreset) -> Void

    init(preset: TimerPreset, isNew: Bool, onSave: @escaping (TimerPreset) -> Void) {
        self.preset = preset
        self.isNew = isNew
        self.onSave = onSave
        _name = State(initialValue: preset.name)
        _workText = State(initialValue: String(preset.work))
        _restText = State(initialValue: String(preset.rest))
        _roundsText = State(initialValue: String(preset.rounds))
        _preparationText = State(initialValue: String(preset.preparationSeconds))
        _preparationEnabled = State(initialValue: preset.preparationEnabled)
        _cooldownText = State(initialValue: String(preset.cooldownSeconds))
        _cooldownEnabled = State(initialValue: preset.cooldownEnabled)
        _selectedSymbol = State(initialValue: preset.symbol)
    }

    private var work: Int? { positiveInteger(workText, range: 1...86_399) }
    private var rest: Int? { positiveInteger(restText, range: 1...86_399) }
    private var rounds: Int? { positiveInteger(roundsText, range: 1...20) }
    private var preparation: Int? { positiveInteger(preparationText, range: 1...86_399) }
    private var cooldown: Int? { positiveInteger(cooldownText, range: 1...86_399) }
    private var cleanedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool {
        !cleanedName.isEmpty
            && work != nil
            && rest != nil
            && rounds != nil
            && (!preparationEnabled || preparation != nil)
            && (!cooldownEnabled || cooldown != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("PRESET") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                selectedSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selectedSymbol == symbol ? TempoPalette.accentInk : TempoPalette.muted)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(
                                        selectedSymbol == symbol ? TempoPalette.lime.opacity(0.45) : TempoPalette.card,
                                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(selectedSymbol == symbol ? TempoPalette.forest : TempoPalette.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Preset icon \(symbol)")
                            .accessibilityAddTraits(selectedSymbol == symbol ? .isSelected : [])
                        }
                    }
                }

                Section("INTERVALS · SECONDS") {
                    secondsField("Work", text: $workText)
                    secondsField("Rest", text: $restText)
                    TextField("Rounds", text: $roundsText)
                        .keyboardType(.numberPad)
                }

                Section("PREPARATION") {
                    Toggle("Add a countdown", isOn: $preparationEnabled)
                    if preparationEnabled {
                        secondsField("Preparation", text: $preparationText)
                    }
                }

                Section("COOLDOWN") {
                    Toggle("After the last set", isOn: $cooldownEnabled)
                    if cooldownEnabled {
                        secondsField("Cooldown", text: $cooldownText)
                    }
                }

                Section {
                    Text("Use any whole number of seconds from 1 to 86,399. Rounds can be 1 to 20.")
                        .font(.footnote)
                        .foregroundStyle(TempoPalette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TempoPalette.canvas)
            .navigationTitle(isNew ? "New Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
        .presentationBackground(TempoPalette.canvas)
    }

    private func secondsField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numberPad)
    }

    private func positiveInteger(_ text: String, range: ClosedRange<Int>) -> Int? {
        guard let value = Int(text), range.contains(value) else { return nil }
        return value
    }

    private func save() {
        guard isValid, let work, let rest, let rounds else { return }
        onSave(TimerPreset(
            id: preset.id,
            name: cleanedName,
            detail: "Custom",
            work: work,
            rest: rest,
            rounds: rounds,
            symbol: selectedSymbol,
            preparationSeconds: preparation ?? preset.preparationSeconds,
            preparationEnabled: preparationEnabled,
            cooldownSeconds: cooldown ?? preset.cooldownSeconds,
            cooldownEnabled: cooldownEnabled
        ))
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

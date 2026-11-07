import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tempo.appearance") private var appearanceModeRaw = AppearanceMode.automatic.rawValue
    @AppStorage("tempo.themeColor") private var themeColorRaw = TempoThemeColor.lime.rawValue
    @AppStorage(CountdownSoundPlayer.settingsKey) private var countdownSoundEnabled = true

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .automatic
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("SOUND") {
                    Toggle("Countdown Beeps", isOn: $countdownSoundEnabled)
                        .tint(TempoPalette.lime)

                    Text("Play a short beep on the final 3 seconds of each interval and a tone when switching phases.")
                        .font(.footnote)
                        .foregroundStyle(TempoPalette.muted)
                }

                Section("APPEARANCE") {
                    Picker("Mode", selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appearanceMode.description)
                        .font(.footnote)
                        .foregroundStyle(TempoPalette.muted)
                }

                Section("THEME COLOR") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(TempoThemeColor.allCases) { themeColor in
                            let isSelected = themeColorRaw == themeColor.rawValue
                            Button {
                                themeColorRaw = themeColor.rawValue
                            } label: {
                                HStack(spacing: 9) {
                                    Circle()
                                        .fill(themeColor.color)
                                        .frame(width: 20, height: 20)
                                    Text(themeColor.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(TempoPalette.ink)
                                    Spacer(minLength: 0)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(TempoPalette.forest)
                                    }
                                }
                                .padding(.horizontal, 11)
                                .frame(height: 44)
                                .background(TempoPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? themeColor.color : TempoPalette.line, lineWidth: isSelected ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(themeColor.title) theme color")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)

                    Text("Choose the accent color used for timer highlights and controls.")
                        .font(.footnote)
                        .foregroundStyle(TempoPalette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TempoPalette.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(TempoPalette.canvas)
    }
}

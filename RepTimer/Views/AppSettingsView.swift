import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tempo.appearance") private var appearanceModeRaw = AppearanceMode.automatic.rawValue
    @AppStorage("tempo.themeColor") private var themeColorRaw = TempoThemeColor.lime.rawValue
    @AppStorage(CountdownSoundPlayer.settingsKey) private var countdownSoundEnabled = true
    @State private var calorieManager = CalorieHealthManager.shared
    @State private var goalText = ""
    @FocusState private var isGoalFieldFocused: Bool

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .automatic
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("DAILY CALORIES WIDGET") {
                    HStack(spacing: 10) {
                        Text("Daily Goal")
                            .foregroundStyle(TempoPalette.ink)

                        Spacer()

                        TextField("2000", text: $goalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 72)
                            .focused($isGoalFieldFocused)
                            .onChange(of: goalText) { _, newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue {
                                    goalText = filtered
                                }
                                if let parsed = Double(filtered), parsed >= CalorieSharedConfig.minDailyGoal {
                                    calorieManager.updateDailyGoal(parsed)
                                }
                            }

                        Text("kcal")
                            .font(.subheadline)
                            .foregroundStyle(TempoPalette.muted)

                        Stepper(
                            "",
                            value: Binding(
                                get: { calorieManager.dailyGoal },
                                set: { newGoal in
                                    calorieManager.updateDailyGoal(newGoal)
                                    goalText = "\(Int(calorieManager.dailyGoal))"
                                }
                            ),
                            in: CalorieSharedConfig.minDailyGoal...CalorieSharedConfig.maxDailyGoal,
                            step: 50
                        )
                        .labelsHidden()
                    }

                    if calorieManager.hasConnectedHealthKit {
                        let summary = calorieManager.todaySummary

                        HStack {
                            Text("Consumed Today")
                                .foregroundStyle(TempoPalette.muted)
                            Spacer()
                            Text("\(Int(summary.consumedCalories.rounded()).formatted()) kcal")
                                .monospacedDigit()
                                .foregroundStyle(TempoPalette.ink)
                        }

                        HStack {
                            Text("Active Exercise")
                                .foregroundStyle(TempoPalette.muted)
                            Spacer()
                            Text("+\(Int(summary.exerciseCalories.rounded()).formatted()) kcal")
                                .monospacedDigit()
                                .foregroundStyle(TempoPalette.ink)
                        }

                        HStack {
                            Text(summary.statusLabel)
                                .fontWeight(.semibold)
                                .foregroundStyle(TempoPalette.ink)
                            Spacer()
                            Text("\(summary.displayValue.formatted()) kcal")
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(summary.isOverBudget ? Color(red: 0.08, green: 0.30, blue: 0.69) : Color(red: 0.13, green: 0.51, blue: 0.96))
                        }

                        Button {
                            Task {
                                await calorieManager.refreshTodayCalories()
                            }
                        } label: {
                            HStack {
                                Label("Sync Apple Health", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if calorieManager.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(calorieManager.isSyncing)
                    } else {
                        Button {
                            Task {
                                await calorieManager.requestAuthorizationAndSync()
                            }
                        } label: {
                            HStack {
                                Label("Connect Apple Health", systemImage: "heart.fill")
                                Spacer()
                                if calorieManager.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(calorieManager.isSyncing || !calorieManager.isHealthDataAvailable)
                    }

                    if let errorMessage = calorieManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Text("Remaining calories are calculated as Daily Goal − Consumed + Active Exercise from Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(TempoPalette.muted)
                }

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
                    Button("Done") {
                        commitGoalText()
                        dismiss()
                    }
                }
            }
            .onAppear {
                goalText = "\(Int(calorieManager.dailyGoal))"
            }
            .onChange(of: isGoalFieldFocused) { _, focused in
                if !focused {
                    commitGoalText()
                }
            }
            .task {
                if calorieManager.hasConnectedHealthKit {
                    await calorieManager.refreshTodayCalories()
                }
            }
        }
        .presentationBackground(TempoPalette.canvas)
    }

    private func commitGoalText() {
        if let parsed = Double(goalText) {
            calorieManager.updateDailyGoal(parsed)
        }
        goalText = "\(Int(calorieManager.dailyGoal))"
    }
}

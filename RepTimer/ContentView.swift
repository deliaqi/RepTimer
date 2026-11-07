import SwiftUI

private struct SetupScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NavigationScrollStateModifier: ViewModifier {
    @Binding var isScrolled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 2
            } action: { _, newValue in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isScrolled = newValue
                }
            }
        } else {
            content.onPreferenceChange(SetupScrollOffsetPreferenceKey.self) { minY in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isScrolled = minY < 0
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var workout = WorkoutTimer()
    @AppStorage("tempo.appearance") private var appearanceModeRaw = AppearanceMode.automatic.rawValue
    @AppStorage("tempo.themeColor") private var themeColorRaw = TempoThemeColor.lime.rawValue
    @State private var selectedPreset: String?
    @State private var editingDuration: EditableDuration?
    @State private var editingPreset: TimerPreset?
    @State private var isSettingsPresented = false
    @State private var customPresets = Self.loadCustomPresets()
    @State private var presetOrder = UserDefaults.standard.stringArray(forKey: "tempo.presetOrder") ?? []
    @State private var isSavePresetPromptPresented = false
    @State private var presetNameDraft = ""
    @State private var isNavigationBlurred = false

    private var allPresets: [TimerPreset] {
        let presets = customPresets
        let defaultOrder = Dictionary(uniqueKeysWithValues: presets.enumerated().map { ($0.element.id, $0.offset) })
        return presets.sorted { first, second in
            let firstOrder = presetOrder.firstIndex(of: first.id) ?? (presetOrder.count + (defaultOrder[first.id] ?? 0))
            let secondOrder = presetOrder.firstIndex(of: second.id) ?? (presetOrder.count + (defaultOrder[second.id] ?? 0))
            return firstOrder < secondOrder
        }
    }

    private static func loadCustomPresets() -> [TimerPreset] {
        guard let data = UserDefaults.standard.data(forKey: "tempo.customPresets"),
              let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) else {
            return []
        }
        return presets
    }

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .automatic
    }

    var body: some View {
        Group {
            if workout.isActive {
                RunningView(workout: workout)
                    .transition(.opacity)
            } else {
                setupView
                    .id(themeColorRaw)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: workout.isActive)
        .preferredColorScheme(selectedAppearance.preferredColorScheme)
        .sheet(item: $editingDuration) { field in
            DurationEditorSheet(title: field.title, seconds: duration(for: field)) { seconds in
                setDuration(field, seconds: seconds)
            }
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorSheet(preset: preset, isNew: preset.name.isEmpty) { savedPreset in
                savePreset(savedPreset)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSettingsPresented) {
            AppSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(selectedAppearance.preferredColorScheme)
        }
        .alert("Save Preset", isPresented: $isSavePresetPromptPresented) {
            TextField("Preset name", text: $presetNameDraft)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { }
            Button("Save") { saveCurrentPreset(named: presetNameDraft) }
                .disabled(presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Save this setup by name. You can customize its icon later from the preset menu.")
        }
    }

    private var setupView: some View {
        ZStack {
            LinearGradient(
                colors: [TempoPalette.canvasTop, TempoPalette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Circle()
                .fill(TempoPalette.lime.opacity(0.27))
                .frame(width: 260, height: 260)
                .blur(radius: 75)
                .offset(x: 180, y: -300)
            Circle()
                .fill(TempoPalette.teal.opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 85)
                .offset(x: -190, y: 350)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SetupScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("tempoSetupScroll")).minY
                        )
                    }
                    .frame(height: 1)
                    headline
                    sessionCard
                    presetSection
                    intervalSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 22)
            }
            .coordinateSpace(name: "tempoSetupScroll")
            .modifier(NavigationScrollStateModifier(isScrolled: $isNavigationBlurred))
            .safeAreaInset(edge: .top, spacing: 0) {
                navigationBar
                    .zIndex(1)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                startBar
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TempoPalette.accentInk)
                    .frame(width: 40, height: 40)
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TempoPalette.lime)
            }
            Text("TEMPO")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(TempoPalette.ink)
            Spacer()
            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TempoPalette.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var navigationBar: some View {
        topBar
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background {
                if isNavigationBlurred {
                    Rectangle()
                        .fill(.thinMaterial)
                        .overlay(TempoPalette.canvas.opacity(0.2))
                        .ignoresSafeArea(edges: .top)
                } else {
                    Color.clear
                }
            }
            .overlay(alignment: .bottom) {
                if isNavigationBlurred {
                    TempoPalette.line.opacity(0.2).frame(height: 0.5)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isNavigationBlurred)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Make every\nminute count.")
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .tracking(-1.4)
                .lineSpacing(-2)
                .foregroundStyle(TempoPalette.ink)
            Text("Set your pace. Focus on the next rep.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TempoPalette.muted)
        }
    }

    private var sessionCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Circle().fill(TempoPalette.lime).frame(width: 7, height: 7)
                    Text("YOUR SESSION")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.66))
                }
                Text("Work. Rest.\nRepeat.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                Text("A simple rhythm for stronger workouts.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(TempoPalette.lime).frame(width: 78, height: 78)
                VStack(spacing: 0) {
                    Text("\(workout.rounds)")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(TempoPalette.accentInk)
                    Text("ROUNDS")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(TempoPalette.accentInk.opacity(0.67))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TempoPalette.forest, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("YOUR PRESETS", trailing: "\(allPresets.count) SAVED")
            if allPresets.isEmpty {
                Text("Your saved presets will appear here. Set your intervals below, then tap Save.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(TempoPalette.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(TempoPalette.line.opacity(0.8), lineWidth: 1))
            } else {
                presetCards
            }
        }
    }

    @ViewBuilder
    private var presetCards: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                presetCardRow
            }
        } else {
            presetCardRow
        }
    }

    private var presetCardRow: some View {
        GeometryReader { proxy in
            let cardWidth = max(104, (proxy.size.width - 20) / 3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allPresets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: selectedPreset == preset.id,
                            action: { applyPreset(preset) },
                            edit: { editingPreset = preset },
                            delete: { deletePreset(preset) }
                        )
                        .frame(width: cardWidth)
                    }
                }
            }
        }
        .frame(height: 142)
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("CUSTOMIZE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(TempoPalette.ink)
                Spacer(minLength: 8)
                Button {
                    presetNameDraft = ""
                    isSavePresetPromptPresented = true
                } label: {
                    Label("SAVE", systemImage: "plus")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(TempoPalette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(TempoPalette.softGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save current settings as a preset")
            }
            VStack(spacing: 0) {
                DurationStepper(
                    title: "WORK",
                    subtitle: "Time to lift",
                    value: workout.workSeconds,
                    tint: TempoPalette.forest,
                    format: formatDuration,
                    decrement: { change(work: -1) },
                    increment: { change(work: 1) },
                    edit: { editingDuration = .work }
                )
                Divider().overlay(TempoPalette.line).padding(.leading, 18)
                DurationStepper(
                    title: "REST",
                    subtitle: "Catch your breath",
                    value: workout.restSeconds,
                    tint: TempoPalette.muted,
                    format: formatDuration,
                    decrement: { change(rest: -1) },
                    increment: { change(rest: 1) },
                    edit: { editingDuration = .rest }
                )
                Divider().overlay(TempoPalette.line).padding(.leading, 18)
                preparationControl
                if workout.preparationEnabled {
                    Divider().overlay(TempoPalette.line).padding(.leading, 18)
                    DurationStepper(
                        title: "PREP",
                        subtitle: "Get set before work",
                        value: workout.preparationSeconds,
                        tint: TempoPalette.teal,
                        format: formatDuration,
                        decrement: { change(preparation: -1) },
                        increment: { change(preparation: 1) },
                        edit: { editingDuration = .preparation }
                    )
                }
                Divider().overlay(TempoPalette.line).padding(.leading, 18)
                cooldownControl
                if workout.cooldownEnabled {
                    Divider().overlay(TempoPalette.line).padding(.leading, 18)
                    DurationStepper(
                        title: "COOLDOWN",
                        subtitle: "Ease out after your last set",
                        value: workout.cooldownSeconds,
                        tint: TempoPalette.teal,
                        format: formatDuration,
                        decrement: { change(cooldown: -1) },
                        increment: { change(cooldown: 1) },
                        edit: { editingDuration = .cooldown }
                    )
                }
                Divider().overlay(TempoPalette.line).padding(.leading, 18)
                RoundStepper(
                    value: workout.rounds,
                    decrement: { change(rounds: -1) },
                    increment: { change(rounds: 1) }
                )
            }
            .background(TempoPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(TempoPalette.line.opacity(0.7), lineWidth: 1))
        }
    }

    private var startBar: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ESTIMATED SESSION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(TempoPalette.muted)
                    Text(formatDuration(workout.totalWorkoutSeconds))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TempoPalette.ink)
                }
                Spacer()
                Text("\(workout.rounds) ROUNDS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(TempoPalette.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(TempoPalette.softGreen, in: Capsule())
            }
            Button {
                workout.start()
            } label: {
                HStack(spacing: 10) {
                    Text("Start workout")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(TempoPalette.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .background(TempoPalette.lime)
            .clipShape(Capsule())
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { TempoPalette.line.frame(height: 1) }
    }

    private var preparationControl: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(TempoPalette.teal)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("PREPARATION")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(TempoPalette.ink)
                Text("Optional countdown before work")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
            }
            Spacer(minLength: 6)
            Toggle("Preparation timer", isOn: Binding(
                get: { workout.preparationEnabled },
                set: { enabled in
                    workout.apply(
                        work: workout.workSeconds,
                        rest: workout.restSeconds,
                        rounds: workout.rounds,
                        preparationEnabled: enabled
                    )
                }
            ))
            .labelsHidden()
            .tint(TempoPalette.lime)
            .accessibilityLabel("Enable preparation countdown")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 66)
    }

    private var cooldownControl: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(TempoPalette.teal)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("COOLDOWN")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(TempoPalette.ink)
                Text("Optional countdown after your last set")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TempoPalette.muted)
            }
            Spacer(minLength: 6)
            Toggle("Cooldown timer", isOn: Binding(
                get: { workout.cooldownEnabled },
                set: { enabled in
                    workout.apply(
                        work: workout.workSeconds,
                        rest: workout.restSeconds,
                        rounds: workout.rounds,
                        cooldownSeconds: workout.cooldownSeconds,
                        cooldownEnabled: enabled
                    )
                }
            ))
            .labelsHidden()
            .tint(TempoPalette.lime)
            .accessibilityLabel("Enable post-workout cooldown")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 66)
    }

    private func sectionHeading(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(TempoPalette.ink)
            Spacer()
            Text(trailing)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(TempoPalette.muted)
        }
    }

    private func change(work: Int = 0, rest: Int = 0, preparation: Int = 0, cooldown: Int = 0, rounds: Int = 0) {
        selectedPreset = nil
        workout.apply(
            work: min(86_399, max(1, workout.workSeconds + work)),
            rest: min(86_399, max(1, workout.restSeconds + rest)),
            rounds: min(20, max(1, workout.rounds + rounds)),
            preparationSeconds: min(86_399, max(1, workout.preparationSeconds + preparation)),
            cooldownSeconds: min(86_399, max(1, workout.cooldownSeconds + cooldown))
        )
    }

    private func duration(for field: EditableDuration) -> Int {
        switch field {
        case .work: workout.workSeconds
        case .rest: workout.restSeconds
        case .preparation: workout.preparationSeconds
        case .cooldown: workout.cooldownSeconds
        }
    }

    private func setDuration(_ field: EditableDuration, seconds: Int) {
        selectedPreset = nil
        workout.apply(
            work: field == .work ? seconds : workout.workSeconds,
            rest: field == .rest ? seconds : workout.restSeconds,
            rounds: workout.rounds,
            preparationSeconds: field == .preparation ? seconds : workout.preparationSeconds,
            cooldownSeconds: field == .cooldown ? seconds : workout.cooldownSeconds
        )
    }

    private func applyPreset(_ preset: TimerPreset) {
        selectedPreset = preset.id
        workout.apply(
            work: preset.work,
            rest: preset.rest,
            rounds: preset.rounds,
            preparationSeconds: preset.preparationSeconds,
            preparationEnabled: preset.preparationEnabled,
            cooldownSeconds: preset.cooldownSeconds,
            cooldownEnabled: preset.cooldownEnabled
        )
        markPresetUsed(preset.id)
    }

    private func savePreset(_ preset: TimerPreset) {
        let isNew = !customPresets.contains { $0.id == preset.id }
        let wasSelected = selectedPreset == preset.id
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        } else {
            customPresets.append(preset)
        }
        customPresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "tempo.customPresets")
        }
        if isNew || wasSelected {
            applyPreset(preset)
        } else {
            markPresetUsed(preset.id)
        }
    }

    private func saveCurrentPreset(named name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        let preset = TimerPreset(
            id: UUID().uuidString,
            name: cleanedName,
            detail: "Custom",
            work: workout.workSeconds,
            rest: workout.restSeconds,
            rounds: workout.rounds,
            symbol: "timer",
            preparationSeconds: workout.preparationSeconds,
            preparationEnabled: workout.preparationEnabled,
            cooldownSeconds: workout.cooldownSeconds,
            cooldownEnabled: workout.cooldownEnabled
        )
        savePreset(preset)
    }

    private func markPresetUsed(_ id: String) {
        presetOrder.removeAll { $0 == id }
        presetOrder.insert(id, at: 0)
        UserDefaults.standard.set(presetOrder, forKey: "tempo.presetOrder")
    }

    private func deletePreset(_ preset: TimerPreset) {
        customPresets.removeAll { $0.id == preset.id }
        presetOrder.removeAll { $0 == preset.id }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "tempo.customPresets")
        }
        UserDefaults.standard.set(presetOrder, forKey: "tempo.presetOrder")
        if selectedPreset == preset.id { selectedPreset = nil }
    }
}

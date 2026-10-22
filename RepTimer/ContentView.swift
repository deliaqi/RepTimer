import SwiftUI
import UIKit

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var description: String {
        switch self {
        case .automatic: "Follow your iPhone’s appearance and schedule."
        case .light: "Keep Tempo in light mode."
        case .dark: "Keep Tempo in dark mode."
        }
    }
}

private enum TempoThemeColor: String, CaseIterable, Identifiable {
    case lime
    case ocean
    case mint
    case violet
    case coral
    case rose

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .lime: Color(hex: 0xD8FF55)
        case .ocean: Color(hex: 0x86C7FF)
        case .mint: Color(hex: 0x64DEC3)
        case .violet: Color(hex: 0xC4A3FF)
        case .coral: Color(hex: 0xFFA987)
        case .rose: Color(hex: 0xF098C3)
        }
    }
}

private enum TempoPalette {
    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static var ink: Color { adaptive(light: 0x171A16, dark: 0xF2F4EE) }
    static let accentInk = Color(hex: 0x171A16)
    static var muted: Color { adaptive(light: 0x777D73, dark: 0xAAB4AA) }
    static var canvas: Color { adaptive(light: 0xF3F4EE, dark: 0x111713) }
    static var canvasTop: Color { adaptive(light: 0xF6F7F1, dark: 0x141B16) }
    static var canvasBottom: Color { adaptive(light: 0xE9EEE2, dark: 0x1B241D) }
    static var card: Color { adaptive(light: 0xFFFFFF, dark: 0x202A23) }
    static var line: Color { adaptive(light: 0xE3E6DD, dark: 0x39453C) }
    static var forest: Color { adaptive(light: 0x263B2B, dark: 0x0E1811) }
    static var softGreen: Color { adaptive(light: 0xE7EEDC, dark: 0x2D3A30) }
    static var runningBackground: Color { adaptive(light: 0x171A16, dark: 0x080C09) }
    static var teal: Color { adaptive(light: 0x5B8A86, dark: 0x8CCFC4) }
    static var preparation: Color { adaptive(light: 0xB9E8DE, dark: 0x467E73) }
    static var rest: Color { adaptive(light: 0xB6DDB9, dark: 0x456C4B) }
    static var lime: Color {
        let rawValue = UserDefaults.standard.string(forKey: "tempo.themeColor") ?? TempoThemeColor.lime.rawValue
        return (TempoThemeColor(rawValue: rawValue) ?? .lime).color
    }
}

private struct TimerPreset: Identifiable, Codable {
    var id: String
    var name: String
    var detail: String
    var work: Int
    var rest: Int
    var rounds: Int
    var symbol: String
    var preparationSeconds: Int = 10
    var preparationEnabled: Bool = false
    var cooldownSeconds: Int = 60
    var cooldownEnabled: Bool = false

    init(
        id: String,
        name: String,
        detail: String,
        work: Int,
        rest: Int,
        rounds: Int,
        symbol: String,
        preparationSeconds: Int = 10,
        preparationEnabled: Bool = false,
        cooldownSeconds: Int = 60,
        cooldownEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.work = work
        self.rest = rest
        self.rounds = rounds
        self.symbol = symbol
        self.preparationSeconds = preparationSeconds
        self.preparationEnabled = preparationEnabled
        self.cooldownSeconds = cooldownSeconds
        self.cooldownEnabled = cooldownEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, detail, work, rest, rounds, symbol
        case preparationSeconds, preparationEnabled, cooldownSeconds, cooldownEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        detail = try values.decodeIfPresent(String.self, forKey: .detail) ?? "Custom"
        work = try values.decode(Int.self, forKey: .work)
        rest = try values.decode(Int.self, forKey: .rest)
        rounds = try values.decode(Int.self, forKey: .rounds)
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "timer"
        preparationSeconds = try values.decodeIfPresent(Int.self, forKey: .preparationSeconds) ?? 10
        preparationEnabled = try values.decodeIfPresent(Bool.self, forKey: .preparationEnabled) ?? false
        cooldownSeconds = try values.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 60
        cooldownEnabled = try values.decodeIfPresent(Bool.self, forKey: .cooldownEnabled) ?? false
    }

}

private enum EditableDuration: String, Identifiable {
    case work
    case rest
    case preparation
    case cooldown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: "Work time"
        case .rest: "Rest time"
        case .preparation: "Preparation time"
        case .cooldown: "Cooldown time"
        }
    }
}

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
                    .fill(TempoPalette.runningBackground)
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
                        .fill(.regularMaterial)
                        .overlay(TempoPalette.canvas.opacity(0.98))
                        .ignoresSafeArea(edges: .top)
                } else {
                    Color.clear
                }
            }
            .overlay(alignment: .bottom) {
                if isNavigationBlurred {
                    TempoPalette.line.opacity(0.7).frame(height: 0.5)
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
                .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
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

private struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tempo.appearance") private var appearanceModeRaw = AppearanceMode.automatic.rawValue
    @AppStorage("tempo.themeColor") private var themeColorRaw = TempoThemeColor.lime.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .automatic
    }

    var body: some View {
        NavigationStack {
            Form {
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

private struct PresetCard: View {
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

private struct PresetEditorSheet: View {
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

private struct DurationStepper: View {
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

private struct RoundStepper: View {
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

private struct StepperButton: View {
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

private struct StepperPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct DurationEditorSheet: View {
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

private struct RunningView: View {
    @ObservedObject var workout: WorkoutTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TempoPalette.runningBackground.ignoresSafeArea()
            Circle()
                .fill(TempoPalette.forest.opacity(0.35))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 170, y: -300)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 24)
                if workout.isComplete {
                    completionContent
                } else {
                    timerContent
                }
                Spacer(minLength: 26)
                controls
            }
            .padding(.horizontal, 24)
            .padding(.top, 15)
            .padding(.bottom, 20)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: workout.phase)
    }

    private var topBar: some View {
        HStack {
            Button {
                workout.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 42, height: 42)
                    .tempoGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End workout")
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(TempoPalette.lime).frame(width: 6, height: 6)
                Text("TEMPO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Text("\(workout.currentRound) / \(workout.rounds)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 54, height: 34)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    private var timerContent: some View {
        VStack(spacing: 25) {
            VStack(spacing: 8) {
                Text(workout.phase.rawValue)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(phaseAccent)
                Text(phasePrompt)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 11)
                TimelineView(.animation(
                    minimumInterval: reduceMotion ? 1 : 1.0 / 30.0,
                    paused: !workout.isRunning
                )) { timeline in
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, workout.progress(at: timeline.date))))
                        .stroke(phaseAccent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: phaseAccent.opacity(0.2), radius: 12)
                }
                VStack(spacing: 0) {
                    Text(clockString(workout.remainingSeconds))
                        .font(.system(size: 68, weight: .medium, design: .rounded).monospacedDigit())
                        .tracking(-2.5)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: workout.remainingSeconds)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("REMAINING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(.top, 4)
                }
            }
            .frame(width: 276, height: 276)

            HStack(spacing: 8) {
                ForEach(1...workout.rounds, id: \.self) { round in
                    Capsule()
                        .fill(round < workout.currentRound ? TempoPalette.lime : round == workout.currentRound ? .white : .white.opacity(0.14))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 15)

            if let next = workout.nextInterval {
                HStack(spacing: 11) {
                    Image(systemName: next.0 == .work ? "dumbbell.fill" : "wind")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TempoPalette.lime)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.0 == .cooldown ? "UP NEXT · COOLDOWN" : "UP NEXT · ROUND \(next.2)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.43))
                        Text("\(next.0.title) · \(clockString(next.1))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(13)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            } else {
                Text(workout.phase == .cooldown ? "COOLDOWN · FINISH STRONG" : "FINAL SET · FINISH STRONG")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
            }
        }
    }

    private var completionContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(TempoPalette.lime).frame(width: 94, height: 94)
                Image(systemName: "checkmark")
                    .font(.system(size: 37, weight: .bold))
                    .foregroundStyle(TempoPalette.accentInk)
            }
            VStack(spacing: 8) {
                Text("WORKOUT\nCOMPLETE")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("That’s another one in the books.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            HStack(spacing: 28) {
                stat(value: "\(workout.rounds)", label: "ROUNDS")
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 35)
                stat(value: clockString(workout.totalWorkoutSeconds), label: "SESSION")
            }
            .padding(.top, 9)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        Group {
            if workout.isComplete {
                Button {
                    workout.stop()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(TempoPalette.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 13) {
                    Button {
                        workout.pauseOrResume()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: workout.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(workout.isRunning ? "Pause" : "Resume")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(TempoPalette.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(TempoPalette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        workout.skipInterval()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 56)
                            .tempoGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip interval")
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var phaseAccent: Color {
        switch workout.phase {
        case .preparation: TempoPalette.preparation
        case .work: TempoPalette.lime
        case .rest: TempoPalette.rest
        case .cooldown: TempoPalette.teal
        }
    }

    private var phasePrompt: String {
        switch workout.phase {
        case .preparation: "Get set. Your first work interval is next."
        case .work: "Give this set your focus."
        case .rest: "Breathe. You’ve earned it."
        case .cooldown: "Ease down. Take a moment to recover."
        }
    }
}

private func formatDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if minutes == 0 { return "\(seconds)s" }
    if remainder == 0 { return "\(minutes):00" }
    return String(format: "%d:%02d", minutes, remainder)
}

private func clockString(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private extension View {
    @ViewBuilder
    func tempoGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

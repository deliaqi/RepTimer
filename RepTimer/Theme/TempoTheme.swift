import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable {
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

enum TempoThemeColor: String, CaseIterable, Identifiable {
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

enum TempoPalette {
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
    static var runningBackground: Color { adaptive(light: 0xF3F4EE, dark: 0x080C09) }
    static var teal: Color { adaptive(light: 0x5B8A86, dark: 0x8CCFC4) }
    static var preparation: Color { adaptive(light: 0x467E73, dark: 0xB9E8DE) }
    static var rest: Color { adaptive(light: 0x456C4B, dark: 0xB6DDB9) }
    static var lime: Color {
        let rawValue = UserDefaults.standard.string(forKey: "tempo.themeColor") ?? TempoThemeColor.lime.rawValue
        return (TempoThemeColor(rawValue: rawValue) ?? .lime).color
    }
}

func formatDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if minutes == 0 { return "\(seconds)s" }
    if remainder == 0 { return "\(minutes):00" }
    return String(format: "%d:%02d", minutes, remainder)
}

func clockString(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
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

extension View {
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

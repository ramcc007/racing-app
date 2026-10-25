import SwiftUI
import UIKit
import EchoLapCore

/// Colours, type and shared modifiers. The race itself is drawn by SpriteKit; menus use native SwiftUI controls,
/// which pick up Liquid Glass automatically on iOS 26 and later.
enum Theme {
    static let background = Color(hex: 0x0E1116)
    static let surface = Color(hex: 0x171B22)
    static let raised = Color(hex: 0x212732)
    static let line = Color.white.opacity(0.10)
    static let text = Color(hex: 0xF2F4F7)
    static let muted = Color(hex: 0x9AA6B4)
    static let accent = Color(hex: 0xF2A93B)
    static let good = Color(hex: 0x5BD08D)
    static let bad = Color(hex: 0xF07A6A)
    static let gold = Color(hex: 0xF2C94C)
    static let spark = Color(hex: 0xFFB547)

    /// Colour-blind-safe lap colours (Okabe–Ito). Every echo also shows its lap number.
    static let echo: [Color] = [0xE69F00, 0x56B4E9, 0x009E73, 0xF0E442, 0x0072B2, 0xD55E00, 0xCC79A7, 0x9AA0A6].map { Color(hex: $0) }
    static let echoUI: [UIColor] = [0xE69F00, 0x56B4E9, 0x009E73, 0xF0E442, 0x0072B2, 0xD55E00, 0xCC79A7, 0x9AA0A6].map { UIColor(hex: $0) }

    static func echoColor(lap: Int) -> Color { echo[(max(1, lap) - 1) % echo.count] }

    static func worldColor(_ world: World) -> Color { Color(hex: WorldStyle.of(world).accent) }

    static func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    /// Big monospaced-digit numbers for timers.
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

// MARK: - Glass

extension View {
    /// Liquid Glass on iOS 26+, a material on earlier versions.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint.opacity(0.35)), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background((tint ?? .clear).opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// A solid card for content that must stay legible over the moving race (no glass over fast motion).
    func solidCard(cornerRadius: CGFloat = 22, fill: Color = Theme.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    /// The prominent action style: Liquid Glass prominent on iOS 26+, a filled capsule before.
    @ViewBuilder
    func primaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent).tint(Theme.accent)
        } else {
            self.buttonStyle(.borderedProminent).tint(Theme.accent).buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder
    func secondaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }
}

// MARK: - Haptics

/// Haptic feedback, off when the player turns it off. Generators are reused so feedback is instant.
@MainActor
enum Haptics {
    static var enabled = true
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()

    static func tap() { guard enabled else { return }; select.selectionChanged() }
    static func light(_ intensity: CGFloat = 1) { guard enabled else { return }; lightImpact.impactOccurred(intensity: intensity) }
    static func medium() { guard enabled else { return }; mediumImpact.impactOccurred() }
    static func heavy() { guard enabled else { return }; heavyImpact.impactOccurred() }
    static func rigid() { guard enabled else { return }; rigidImpact.impactOccurred() }
    static func success() { guard enabled else { return }; notice.notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; notice.notificationOccurred(.warning) }
}

// MARK: - World looks

/// Palette and scenery per world, shared by the race scene and the menus.
struct WorldStyle {
    let ground: UInt32
    let groundDetail: UInt32
    let asphalt: UInt32
    let kerbA: UInt32
    let kerbB: UInt32
    let accent: UInt32
    let scenery: Scenery

    enum Scenery { case harbour, canyon, neon, glacier, jungle, foundry, sky, space }

    static func of(_ world: World) -> WorldStyle {
        switch world {
        case .harbour: return WorldStyle(ground: 0xC9C2B4, groundDetail: 0xB8B0A1, asphalt: 0x3B3F47, kerbA: 0xE8E4DA, kerbB: 0xD64545, accent: 0x3F8FD2, scenery: .harbour)
        case .canyon: return WorldStyle(ground: 0xD9925B, groundDetail: 0xC97E49, asphalt: 0x4A3A33, kerbA: 0xF2E2C4, kerbB: 0x9C4A2A, accent: 0xE07A3F, scenery: .canyon)
        case .neon: return WorldStyle(ground: 0x1D1B33, groundDetail: 0x26234A, asphalt: 0x2A2A40, kerbA: 0x3A3760, kerbB: 0xE84DD1, accent: 0x43E0FF, scenery: .neon)
        case .glacier: return WorldStyle(ground: 0xDDEFF7, groundDetail: 0xC6E2EE, asphalt: 0x5F7F96, kerbA: 0xFFFFFF, kerbB: 0x2C6E9B, accent: 0x2C9BD6, scenery: .glacier)
        case .jungle: return WorldStyle(ground: 0x3E7D45, groundDetail: 0x356C3B, asphalt: 0x5B4B3A, kerbA: 0xF2E2C4, kerbB: 0xE3C16F, accent: 0xE3C16F, scenery: .jungle)
        case .foundry: return WorldStyle(ground: 0x2B2523, groundDetail: 0x372F2C, asphalt: 0x3A3433, kerbA: 0x5A504C, kerbB: 0xFF7A1A, accent: 0xFF7A1A, scenery: .foundry)
        case .skyport: return WorldStyle(ground: 0x9FD3F0, groundDetail: 0x8CC6E8, asphalt: 0x5E6B7A, kerbA: 0xFFFFFF, kerbB: 0x3F8FD2, accent: 0xFFFFFF, scenery: .sky)
        case .orbit: return WorldStyle(ground: 0x0C1022, groundDetail: 0x151A33, asphalt: 0x2C3150, kerbA: 0x3C426A, kerbB: 0xB49BFF, accent: 0xB49BFF, scenery: .space)
        }
    }
}

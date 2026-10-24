import SwiftUI

enum Theme {

    static let duskNavy = Color(hex: 0x101E36)
    static let atmosphereTeal = Color(hex: 0x2E7D8C)
    static let heatAmber = Color(hex: 0xE8963C)
    static let blazeRed = Color(hex: 0xD8432E)

    
    static let asphaltGray = Color(hex: 0x3A3B3E)
    static let mist = Color(hex: 0xF4F6F8)

    
    private static let stops: [Color] = [duskNavy, atmosphereTeal, heatAmber, blazeRed]

    static func thermalColor(for value: Double, min minValue: Double, max maxValue: Double) -> Color {
        let clamped = Swift.min(Swift.max(value, minValue), maxValue)
        let fraction = maxValue > minValue ? (clamped - minValue) / (maxValue - minValue) : 0
        let segment = fraction * Double(stops.count - 1)
        let lowerIndex = Swift.min(Int(segment), stops.count - 2)
        let localFraction = segment - Double(lowerIndex)
        return Color.blend(stops[lowerIndex], stops[lowerIndex + 1], amount: localFraction)
    }

    
    
    static func deltaColor(_ delta: Double) -> Color {
        thermalColor(for: delta, min: -2, max: 8)
    }

    
    static func ambientColor(_ celsius: Double) -> Color {
        thermalColor(for: celsius, min: 2, max: 34)
    }
    
    static func heroGradient(centeredOn value: Double, min minValue: Double, max maxValue: Double) -> LinearGradient {
        
        
        let base = Color.blend(thermalColor(for: value, min: minValue, max: maxValue), duskNavy, amount: 0.35)
        return LinearGradient(
            colors: [duskNavy, base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func surfaceTint(for surfaceType: SurfaceType) -> Color {
        switch surfaceType {
        case .asphalt: return blazeRed
        case .rooftop: return heatAmber
        case .concrete: return asphaltGray
        case .grass: return Color(hex: 0x4C9A5B)
        case .treeShade: return Color(hex: 0x2F6B3A)
        case .water: return atmosphereTeal
        case .other: return Color(hex: 0x7B6CA8)
        }
    }

    static func surfaceIcon(for surfaceType: SurfaceType) -> String {
        switch surfaceType {
        case .asphalt: return "road.lanes"
        case .rooftop: return "house.fill"
        case .concrete: return "square.grid.3x3.fill"
        case .grass: return "leaf.fill"
        case .treeShade: return "tree.fill"
        case .water: return "drop.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    static func readoutFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    
    static func labelFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    
    
    static func blend(_ from: Color, _ to: Color, amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        let f = from.resolveRGBA()
        let s = to.resolveRGBA()
        return Color(
            red: f.r + (s.r - f.r) * t,
            green: f.g + (s.g - f.g) * t,
            blue: f.b + (s.b - f.b) * t
        )
    }

    private func resolveRGBA() -> (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        return (0, 0, 0, 1)
        #endif
    }
}

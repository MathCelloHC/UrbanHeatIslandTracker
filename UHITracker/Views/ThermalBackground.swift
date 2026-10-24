import SwiftUI

struct ThermalBackground: View {
    var temperature: Double? = nil

    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    private var horizon: Color { Theme.ambientColor(temperature ?? 20) }

    private var skyColors: [Color] {
        if isDark {
            return [
                Theme.duskNavy,
                Color.blend(Theme.duskNavy, horizon, amount: 0.30),
                Color.blend(Theme.duskNavy, horizon, amount: 0.65)
            ]
        } else {
            return [
                Color(hex: 0xE9F1F7),
                Color.blend(Theme.mist, horizon, amount: 0.18),
                Color.blend(Theme.mist, horizon, amount: 0.40)
            ]
        }
    }

    private var skylineColors: [Color] {
        if isDark {
            return [Color(hex: 0x0B1526).opacity(0.55), Color(hex: 0x070E1A).opacity(0.95)]
        } else {
            return [Color(hex: 0x3B4C63).opacity(0.10), Color(hex: 0x3B4C63).opacity(0.28)]
        }
    }

    private var isobarColor: Color {
        isDark ? Color.white.opacity(0.07) : Theme.duskNavy.opacity(0.07)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)

            RadialGradient(
                colors: [horizon.opacity(isDark ? 0.55 : 0.35), horizon.opacity(0)],
                center: .bottom,
                startRadius: 0,
                endRadius: 520
            )

            IsobarLines()
                .stroke(isobarColor, lineWidth: 1)

            VStack(spacing: 0) {
                Spacer()
                SkylineShape()
                    .fill(LinearGradient(colors: skylineColors, startPoint: .top, endPoint: .bottom))
                    .frame(height: 180)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct IsobarLines: Shape {
    var lines = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 else { return path }

        for i in 0..<lines {
            let baseY = rect.height * (0.10 + CGFloat(i) * 0.11)
            let amplitude = 14 + CGFloat(i) * 5
            let phase = CGFloat(i) * 0.9

            path.move(to: CGPoint(x: rect.minX, y: baseY + sin(phase) * amplitude))
            for x in stride(from: CGFloat(0), through: rect.width, by: 6) {
                let angle = (x / rect.width) * 2 * .pi * 1.3 + phase
                path.addLine(to: CGPoint(x: rect.minX + x, y: baseY + sin(angle) * amplitude))
            }
        }
        return path
    }
}

struct SkylineShape: Shape {
    private static let buildings: [(w: CGFloat, h: CGFloat)] = [
        (0.08, 0.45), (0.06, 0.70), (0.09, 0.55), (0.05, 0.85), (0.08, 0.60),
        (0.07, 0.40), (0.06, 0.75), (0.09, 0.50), (0.05, 0.95), (0.08, 0.65),
        (0.07, 0.45), (0.06, 0.60), (0.10, 0.50), (0.06, 0.35)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0
        for building in Self.buildings {
            let width = rect.width * building.w
            let height = rect.height * building.h
            // +1 on width hides hairline gaps between neighbours.
            path.addRect(CGRect(x: rect.minX + x, y: rect.maxY - height, width: width + 1, height: height))
            x += width
        }
        return path
    }
}

#Preview("Light, mild") {
    ThermalBackground(temperature: 18)
}

#Preview("Dark, hot") {
    ThermalBackground(temperature: 32)
        .preferredColorScheme(.dark)
}

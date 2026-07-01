import SwiftUI
import UIKit

// MARK: - 0–140 dB 声学生活场景区间（与表盘渐变 stop 严格等比例）

enum AcousticGaugeStyle {
    /// 全量声学标度（颜色 / 场景文案仍按 0–140 映射）。
    static let minDecibel: Float = 0
    static let maxDecibel: Float = 140
    static let span: Float = maxDecibel - minDecibel

    /// 表盘弧可视起点（左侧刻度从 20 起）。
    static let displayMinDecibel: Float = 20
    static let displayMaxDecibel: Float = 140
    static let displaySpan: Float = displayMaxDecibel - displayMinDecibel

    /// 马蹄形弧：SwiftUI 标准角（0° = 3 点钟，顺时针），240° 扫掠。
    static let arcStartDegrees: Double = 150
    static let arcEndDegrees: Double = 390
    static let arcSweepDegrees: Double = arcEndDegrees - arcStartDegrees

    static let trackColor = Color.white.opacity(0.10)
    static let tickMajorColor = Color.white.opacity(0.42)
    static let tickMinorColor = Color.white.opacity(0.18)

    private static let gradientStopSpecs: [(placement: Double, hex: String)] = [
        (0.00, "#10B981"), // 0 dB — Total Silence
        (0.21, "#10B981"), // 30 dB — Quiet Library
        (0.36, "#FBBF24"), // 50 dB — Normal Conversation
        (0.46, "#F97316"), // 65 dB — City Traffic
        (0.57, "#EF4444"), // 80 dB — Lawn Mower
        (0.71, "#DC2626"), // 100 dB — Police Siren
        (1.00, "#7F1D1D"), // 140 dB — Threshold of Pain
    ]

    static var gradientStops: [Gradient.Stop] {
        gradientStopSpecs.map { spec in
            .init(color: industrialColor(hex: spec.hex), location: spec.placement)
        }
    }

    static var angularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: gradientStops),
            center: .center,
            startAngle: .degrees(arcStartDegrees),
            endAngle: .degrees(arcEndDegrees)
        )
    }

    /// 归一化位置 t ∈ [0, 1]，与 0–140 dB 线性对应（用于渐变色）。
    static func normalizedPosition(forDecibel db: Float) -> Double {
        let clamped = min(max(db, minDecibel), maxDecibel)
        return Double((clamped - minDecibel) / span)
    }

    /// 表盘弧上的归一化位置（20–140 dB → 0–1）。
    static func arcNormalizedPosition(forDecibel db: Float) -> Double {
        let clamped = min(max(db, displayMinDecibel), displayMaxDecibel)
        return Double((clamped - displayMinDecibel) / displaySpan)
    }

    static func angleDegrees(forDecibel db: Float) -> Double {
        arcStartDegrees + arcNormalizedPosition(forDecibel: db) * arcSweepDegrees
    }

    static func color(forDecibel db: Float) -> Color {
        interpolatedColor(at: normalizedPosition(forDecibel: db))
    }

    static func ambientNoiseDescription(forDecibel db: Float) -> String {
        switch db {
        case ..<30: L10n.gaugeAmbientTotalSilence
        case 30..<50: L10n.gaugeAmbientQuietLibrary
        case 50..<65: L10n.gaugeAmbientNormalConversation
        case 65..<80: L10n.gaugeAmbientCityTraffic
        case 80..<100: L10n.gaugeAmbientLawnMower
        default: L10n.gaugeAmbientJetTakeoff
        }
    }

    /// 当前区间上边界在渐变上的颜色（用于指针与标签联动）。
    static func zoneAccentColor(forDecibel db: Float) -> Color {
        let boundary: Float = switch db {
        case ..<30: 30
        case 30..<50: 50
        case 50..<65: 65
        case 65..<80: 80
        case 80..<100: 100
        default: 140
        }
        return color(forDecibel: boundary)
    }

    private static func industrialColor(hex: String) -> Color {
        Color(hex: hex)
    }

    private static func interpolatedColor(at position: Double) -> Color {
        let t = min(max(position, 0), 1)
        guard let upperIndex = gradientStopSpecs.firstIndex(where: { $0.placement >= t }) else {
            return industrialColor(hex: gradientStopSpecs.last?.hex ?? "#10B981")
        }
        let lowerIndex = max(upperIndex - 1, 0)
        if lowerIndex == upperIndex {
            return industrialColor(hex: gradientStopSpecs[upperIndex].hex)
        }

        let lower = gradientStopSpecs[lowerIndex]
        let upper = gradientStopSpecs[upperIndex]
        let range = upper.placement - lower.placement
        let localT = range > 0 ? (t - lower.placement) / range : 0
        return industrialColor(hex: lower.hex).interpolated(
            to: industrialColor(hex: upper.hex),
            amount: localT
        )
    }

    static func uiColor(forDecibel db: Float) -> UIColor {
        UIColor(color(forDecibel: db))
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    fileprivate func interpolated(to target: Color, amount: Double) -> Color {
        let amount = min(max(amount, 0), 1)
        let source = rgbaComponents
        let destination = target.rgbaComponents
        return Color(
            red: source.red + (destination.red - source.red) * amount,
            green: source.green + (destination.green - source.green) * amount,
            blue: source.blue + (destination.blue - source.blue) * amount,
            opacity: source.opacity + (destination.opacity - source.opacity) * amount
        )
    }

    private var rgbaComponents: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(UIKit)
        typealias PlatformColor = UIColor
        #else
        typealias PlatformColor = NSColor
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        PlatformColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}

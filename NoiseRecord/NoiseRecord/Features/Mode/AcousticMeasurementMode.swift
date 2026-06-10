import SwiftUI

/// User-facing acoustic measurement modes mapped to underlying DSP weighting.
enum AcousticMeasurementMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case highSensitivity

    var id: String { rawValue }

    var isHighSensitivity: Bool {
        self == .highSensitivity
    }

    init(isHighSensitivity: Bool) {
        self = isHighSensitivity ? .highSensitivity : .standard
    }

    // MARK: - Product copy (do not paraphrase)

    var userFacingTitle: String {
        switch self {
        case .standard: "人耳听感模式"
        case .highSensitivity: "全频/低频侦测"
        }
    }

    var userFacingSubtitle: String {
        switch self {
        case .standard: "日常听感评估"
        case .highSensitivity: "物理声压"
        }
    }

    /// Segmented control short label.
    var segmentLabel: String {
        switch self {
        case .standard: "标准听感"
        case .highSensitivity: "全频高灵敏"
        }
    }

    var technicalBadge: String {
        switch self {
        case .standard: "dBA"
        case .highSensitivity: "dBZ / dBC"
        }
    }

    var coreDescription: String {
        switch self {
        case .standard:
            "模拟人类耳朵对声音的真实感受。自动过滤掉人耳不敏感的极高频和极低频声音。"
        case .highSensitivity:
            "关闭一切人耳滤镜与手机系统降噪，100% 捕捉空气中全部的物理声波能量。"
        }
    }

    /// Full tooltip copy — verbatim per product spec.
    var tooltipCopy: String {
        switch self {
        case .standard:
            "【标准听感】最贴近您主观听觉的模式。适合用来测量日常谈话、电视噪音、商场嘈杂度或邻里大喊大叫。国家住宅噪音标准（如夜间不得超过 45 分贝）均基于此模式测算。"
        case .highSensitivity:
            "【全频高灵敏】捕获空气中真实的物理能量。在看似安静的深夜房间里，该模式会敏锐捕捉到隔壁空调外机共振、冰箱压缩机嗡嗡声、建筑管道风噪等‘隐形低频杀手’。数据通常高于普通模式，是您寻找隐性噪音源、机器异响检测和维权取证的终极利器。"
        }
    }

    var tooltipHeadline: String {
        switch self {
        case .standard: "【标准听感】"
        case .highSensitivity: "【全频高灵敏】"
        }
    }

    var comparisonHint: String {
        switch self {
        case .standard:
            "读数更贴近您「听起来有多吵」的主观感受，适合对照国家噪音标准。"
        case .highSensitivity:
            "读数通常高于标准模式，这是正常现象——它在测量您「听不见但确实存在」的物理声波。"
        }
    }
}

struct ModeVisualTheme {
    let accent: Color
    let secondaryAccent: Color
    let gaugeGradient: [Color]
    let waveformGradient: [Color]
    let waveformLineWidth: CGFloat
    let cardTint: Color
    let badgeForeground: Color
    let badgeBackground: Color

    static func theme(for mode: AcousticMeasurementMode) -> ModeVisualTheme {
        switch mode {
        case .standard:
            ModeVisualTheme(
                accent: Color(red: 0.18, green: 0.55, blue: 0.72),
                secondaryAccent: Color(red: 0.12, green: 0.68, blue: 0.52),
                gaugeGradient: [
                    Color(red: 0.12, green: 0.68, blue: 0.52),
                    Color(red: 0.18, green: 0.55, blue: 0.72),
                    Color(red: 0.22, green: 0.42, blue: 0.78),
                ],
                waveformGradient: [
                    Color(red: 0.12, green: 0.68, blue: 0.52),
                    Color(red: 0.18, green: 0.55, blue: 0.72),
                    Color(red: 0.28, green: 0.45, blue: 0.85),
                ],
                waveformLineWidth: 2,
                cardTint: Color(red: 0.12, green: 0.55, blue: 0.72).opacity(0.08),
                badgeForeground: Color(red: 0.15, green: 0.62, blue: 0.78),
                badgeBackground: Color(red: 0.12, green: 0.55, blue: 0.72).opacity(0.14)
            )
        case .highSensitivity:
            ModeVisualTheme(
                accent: Color(red: 1.0, green: 0.45, blue: 0.12),
                secondaryAccent: Color(red: 0.72, green: 0.35, blue: 0.95),
                gaugeGradient: [
                    Color(red: 1.0, green: 0.45, blue: 0.12),
                    Color(red: 0.95, green: 0.28, blue: 0.55),
                    Color(red: 0.62, green: 0.35, blue: 0.98),
                ],
                waveformGradient: [
                    Color(red: 1.0, green: 0.55, blue: 0.1),
                    Color(red: 0.98, green: 0.32, blue: 0.48),
                    Color(red: 0.68, green: 0.38, blue: 1.0),
                ],
                waveformLineWidth: 2.5,
                cardTint: Color(red: 1.0, green: 0.45, blue: 0.12).opacity(0.1),
                badgeForeground: Color(red: 1.0, green: 0.52, blue: 0.18),
                badgeBackground: Color(red: 0.72, green: 0.35, blue: 0.95).opacity(0.18)
            )
        }
    }
}

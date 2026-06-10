import Foundation
import UIKit

enum SilenceGrade: String, CaseIterable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var title: String {
        switch self {
        case .a: "极佳静音"
        case .b: "良好"
        case .c: "一般"
        case .d: "嘈杂"
        }
    }

    var description: String {
        switch self {
        case .a: "Leq < 35 dB，适合睡眠与录音"
        case .b: "Leq 35–45 dB，居住环境良好"
        case .c: "Leq 45–55 dB，有明显环境噪声"
        case .d: "Leq > 55 dB，建议排查噪声源"
        }
    }

    static func from(leq: Float) -> SilenceGrade {
        switch leq {
        case ..<35: .a
        case 35..<45: .b
        case 45..<55: .c
        default: .d
        }
    }
}

struct SilenceRatingReport: Sendable {
    let grade: SilenceGrade
    let leq: Float
    let maxDB: Float
    let minDB: Float
    let averageDB: Float
    let weighting: WeightingType
    let generatedAt: Date
    let deviceModel: String

    init(leq: Float, maxDB: Float, minDB: Float, averageDB: Float, weighting: WeightingType) {
        self.leq = leq
        self.maxDB = maxDB
        self.minDB = minDB
        self.averageDB = averageDB
        self.weighting = weighting
        self.grade = SilenceGrade.from(leq: leq)
        self.generatedAt = Date()
        self.deviceModel = DeviceCalibrationStore.deviceModelIdentifier
    }

    var summaryText: String {
        """
        静音评级报告
        生成时间：\(formattedDate(generatedAt))
        设备：\(deviceModel)
        计权：\(weighting.displayName)

        评级：\(grade.rawValue) - \(grade.title)
        \(grade.description)

        Leq：\(String(format: "%.1f", leq)) dB
        最大：\(String(format: "%.1f", maxDB)) dB
        最小：\(String(format: "%.1f", minDB)) dB
        平均：\(String(format: "%.1f", averageDB)) dB

        免责声明：本报告基于手机麦克风参考级测量，非认证声级计，仅供参考。
        """
    }

    func renderShareImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.label,
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.secondaryLabel,
            ]

            summaryText.draw(
                in: CGRect(x: 32, y: 32, width: 536, height: 736),
                withAttributes: bodyAttrs.merging(titleAttrs) { _, new in new }
            )
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f.string(from: date)
    }
}

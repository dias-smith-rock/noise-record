import Foundation
import UIKit

enum SilenceGrade: String, CaseIterable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var title: String { localizedTitle }
    var description: String { localizedDescription }

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
        \(String(localized: "silenceReport.header"))
        \(String(localized: "silenceReport.generated")) \(formattedDate(generatedAt))
        \(String(localized: "silenceReport.device")) \(deviceModel)
        \(String(localized: "silenceReport.weighting")) \(weighting.displayName)

        \(String(localized: "silenceReport.grade")) \(String(format: String(localized: "silenceReport.gradeLine"), grade.rawValue, grade.title))
        \(grade.description)

        \(String(localized: "silenceReport.leq")) \(String(format: "%.1f", leq)) dB
        \(String(localized: "silenceReport.max")) \(String(format: "%.1f", maxDB)) dB
        \(String(localized: "silenceReport.min")) \(String(format: "%.1f", minDB)) dB
        \(String(localized: "silenceReport.avg")) \(String(format: "%.1f", averageDB)) dB

        \(String(localized: "silenceReport.disclaimer"))
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

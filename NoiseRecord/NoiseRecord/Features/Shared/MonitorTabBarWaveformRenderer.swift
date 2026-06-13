import UIKit

enum MonitorTabBarWaveformRenderer {
    private static let canvasSize = CGSize(width: 27, height: 27)
    private static let barCount = 5
    private static let barWidth: CGFloat = 2.5
    private static let barSpacing: CGFloat = 1.5
    private static let maxBarHeight: CGFloat = 14
    private static let minBarHeight: CGFloat = 3

    static func render(at time: TimeInterval) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { _ in
            let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
            var x = (canvasSize.width - totalWidth) / 2
            let midY = canvasSize.height / 2

            UIColor.black.setFill()
            for index in 0..<barCount {
                let height = barHeight(for: index, at: time)
                let rect = CGRect(
                    x: x,
                    y: midY - height / 2,
                    width: barWidth,
                    height: height
                )
                UIBezierPath(roundedRect: rect, cornerRadius: 1).fill()
                x += barWidth + barSpacing
            }
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func barHeight(for index: Int, at time: TimeInterval) -> CGFloat {
        let seed = Double(index) * 1.17
        let t = time * 6.0
        let primary = sin(t + seed)
        let secondary = sin(t * 1.55 + seed * 0.8) * 0.55
        let tertiary = sin(t * 2.35 + seed * 1.35) * 0.28
        let mix = (primary + secondary + tertiary + 1.83) / 3.66
        return minBarHeight + CGFloat(mix) * (maxBarHeight - minBarHeight)
    }
}

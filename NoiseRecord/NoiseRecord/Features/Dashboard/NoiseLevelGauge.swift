import SwiftUI

// MARK: - 刻度与色带

private enum DecibelGaugeScale {
    static let minDB: Float = 20
    static let maxDB: Float = 140
    static let span: Float = maxDB - minDB

    static let quietUpper: Float = 50
    static let moderateUpper: Float = 90

    /// 表盘弧起点（7:30）与扫掠角（经 12 点至 4:30，底部留空）。
    static let startClockDegrees: Double = 225
    static let sweepDegrees: Double = 270

    static let quietColor = Color(red: 0.28, green: 0.76, blue: 0.48)
    static let moderateColor = Color(red: 1.0, green: 0.62, blue: 0.18)
    static let loudColor = Color(red: 0.94, green: 0.27, blue: 0.24)
    static let trackColor = Color.primary.opacity(0.10)
    static let tickMajorColor = Color.primary.opacity(0.42)
    static let tickMinorColor = Color.primary.opacity(0.18)
    static let needleColor = Color(red: 0.94, green: 0.27, blue: 0.24)
}

struct NoiseLevelGauge: View {
    let db: Float
    var mode: AcousticMeasurementMode = .standard
    var humidityText: String = "--"
    var temperatureText: String = "--"
    var hidesFullscreenButton: Bool = false
    var onFullscreenTap: (() -> Void)?

    private var theme: ModeVisualTheme { .theme(for: mode) }
    private var risk: NoiseRiskLevel { .from(db: db, highSensitivity: mode.isHighSensitivity) }

    private var animatedDB: Float {
        (db * 2).rounded() / 2
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                gaugeDial
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)

                if let onFullscreenTap {
                    fullscreenButton(action: onFullscreenTap)
                        .padding(.top, 2)
                        .opacity(hidesFullscreenButton ? 0 : 1)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: FullscreenGuideButtonFrameKey.self,
                                    value: proxy.frame(in: .global)
                                )
                            }
                        }
                }
            }

            HStack(spacing: 18) {
                EnvironmentInlineMetric(
                    symbol: "drop.fill",
                    text: humidityText,
                    tint: Color(red: 0.35, green: 0.68, blue: 0.92)
                )

                Text(risk.label)
                    .font(.subheadline)
                    .foregroundStyle(risk.color)
                    .multilineTextAlignment(.center)

                EnvironmentInlineMetric(
                    symbol: "thermometer.medium",
                    text: temperatureText,
                    tint: Color(red: 0.95, green: 0.55, blue: 0.28)
                )
            }
            .frame(maxWidth: .infinity)

            if mode.isHighSensitivity {
                Text(L10n.gaugeHighSensitivityHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func fullscreenButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(theme.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.dashboardFullscreenLED)
    }

    private var gaugeDial: some View {
        GeometryReader { geometry in
            let layout = GaugeLayout(size: geometry.size)

            ZStack {
                Canvas { context, _ in
                    drawTrack(context: &context, layout: layout)
                    drawColorZones(context: &context, layout: layout)
                    drawTicks(context: &context, layout: layout)
                    drawNeedle(context: &context, layout: layout, db: animatedDB)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", db))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.08), value: animatedDB)

                    Text(mode.technicalBadge)
                        .font(.caption.bold())
                        .foregroundStyle(theme.accent)
                }
                .position(x: layout.center.x, y: layout.center.y + layout.size * 0.06)
            }
        }
        .aspectRatio(1.15, contentMode: .fit)
        .padding(.horizontal, 8)
    }

    // MARK: - Canvas 绘制

    private func drawTrack(context: inout GraphicsContext, layout: GaugeLayout) {
        let path = layout.arcPath(from: DecibelGaugeScale.minDB, to: DecibelGaugeScale.maxDB)
        context.stroke(
            path,
            with: .color(DecibelGaugeScale.trackColor),
            style: StrokeStyle(lineWidth: layout.trackWidth, lineCap: .round)
        )
    }

    private func drawColorZones(context: inout GraphicsContext, layout: GaugeLayout) {
        let zones: [(Float, Float, Color)] = [
            (DecibelGaugeScale.minDB, DecibelGaugeScale.quietUpper, DecibelGaugeScale.quietColor),
            (DecibelGaugeScale.quietUpper, DecibelGaugeScale.moderateUpper, DecibelGaugeScale.moderateColor),
            (DecibelGaugeScale.moderateUpper, DecibelGaugeScale.maxDB, DecibelGaugeScale.loudColor),
        ]

        for (start, end, color) in zones {
            let path = layout.arcPath(from: start, to: end)
            context.stroke(
                path,
                with: .color(color.opacity(0.92)),
                style: StrokeStyle(lineWidth: layout.zoneWidth, lineCap: .butt)
            )
        }
    }

    private func drawTicks(context: inout GraphicsContext, layout: GaugeLayout) {
        var db = DecibelGaugeScale.minDB
        while db <= DecibelGaugeScale.maxDB + 0.1 {
            let isMajor = Int(db) % 20 == 0
            let outer = layout.point(for: db, radius: layout.radius)
            let inner = layout.point(
                for: db,
                radius: layout.radius - (isMajor ? layout.majorTickLength : layout.minorTickLength)
            )

            var tick = Path()
            tick.move(to: outer)
            tick.addLine(to: inner)
            context.stroke(
                tick,
                with: .color(isMajor ? DecibelGaugeScale.tickMajorColor : DecibelGaugeScale.tickMinorColor),
                style: StrokeStyle(lineWidth: isMajor ? 1.5 : 0.75, lineCap: .round)
            )

            if isMajor {
                let labelPoint = layout.point(for: db, radius: layout.radius - layout.labelInset)
                let resolved = context.resolve(
                    Text("\(Int(db))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                )
                context.draw(resolved, at: labelPoint, anchor: .center)
            }

            db += 10
        }
    }

    private func drawNeedle(context: inout GraphicsContext, layout: GaugeLayout, db: Float) {
        let hub = layout.center
        let tip = layout.point(for: db, radius: layout.radius - layout.zoneWidth * 0.5 - 6)

        var needle = Path()
        needle.move(to: hub)
        needle.addLine(to: tip)
        context.stroke(
            needle,
            with: .color(DecibelGaugeScale.needleColor),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        let hubRadius: CGFloat = 5
        let hubRect = CGRect(
            x: hub.x - hubRadius,
            y: hub.y - hubRadius,
            width: hubRadius * 2,
            height: hubRadius * 2
        )
        context.fill(Path(ellipseIn: hubRect), with: .color(DecibelGaugeScale.needleColor))
        context.fill(
            Path(ellipseIn: hubRect.insetBy(dx: 1.5, dy: 1.5)),
            with: .color(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 几何布局

private struct GaugeLayout {
    let center: CGPoint
    let radius: CGFloat
    let size: CGFloat
    let trackWidth: CGFloat = 6
    let zoneWidth: CGFloat = 10
    let majorTickLength: CGFloat = 12
    let minorTickLength: CGFloat = 6
    let labelInset: CGFloat = 22

    init(size: CGSize) {
        let side = min(size.width, size.height)
        self.size = side
        self.radius = side * 0.40
        self.center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
    }

    func point(for db: Float, radius: CGFloat) -> CGPoint {
        let clamped = min(max(db, DecibelGaugeScale.minDB), DecibelGaugeScale.maxDB)
        let fraction = CGFloat((clamped - DecibelGaugeScale.minDB) / DecibelGaugeScale.span)
        let degrees = DecibelGaugeScale.startClockDegrees + Double(fraction) * DecibelGaugeScale.sweepDegrees
        let radians = (degrees - 90) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    func arcPath(from startDB: Float, to endDB: Float) -> Path {
        var path = Path()
        let steps = max(2, Int((endDB - startDB) / 4))
        for step in 0...steps {
            let db = startDB + (endDB - startDB) * Float(step) / Float(steps)
            let point = point(for: db, radius: radius)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct EnvironmentInlineMetric: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

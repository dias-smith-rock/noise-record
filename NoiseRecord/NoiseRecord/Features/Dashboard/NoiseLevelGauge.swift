import SwiftUI

struct NoiseLevelGauge: View {
    let db: Float
    var mode: AcousticMeasurementMode = .standard
    var humidityText: String = "--"
    var temperatureText: String = "--"
    var hidesFullscreenButton: Bool = false
    var onFullscreenTap: (() -> Void)?

    private var theme: ModeVisualTheme { .theme(for: mode) }

    private var animatedDB: Float {
        (db * 2).rounded() / 2
    }

    private var ambientNoiseDescription: String {
        AcousticGaugeStyle.ambientNoiseDescription(forDecibel: db)
    }

    private var zoneAccentColor: Color {
        AcousticGaugeStyle.zoneAccentColor(forDecibel: db)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                gaugeDial
                    .frame(height: 198)
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

                Text(ambientNoiseDescription)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(zoneAccentColor)
                    .multilineTextAlignment(.center)
                    .shadow(color: zoneAccentColor.opacity(0.30), radius: 5)
                    .animation(.easeOut(duration: 0.18), value: ambientNoiseDescription)

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
                    drawGradientArc(context: &context, layout: layout)
                    drawTicks(context: &context, layout: layout)
                    drawNeedle(context: &context, layout: layout, db: animatedDB)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", db))
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.08), value: animatedDB)
                }
                .position(x: layout.center.x, y: layout.center.y + layout.size * 0.04)
            }
        }
        .aspectRatio(1.12, contentMode: .fit)
        .padding(.horizontal, 2)
    }

    // MARK: - Canvas

    private func drawTrack(context: inout GraphicsContext, layout: GaugeLayout) {
        let path = layout.arcPath(
            from: AcousticGaugeStyle.displayMinDecibel,
            to: AcousticGaugeStyle.displayMaxDecibel
        )
        context.stroke(
            path,
            with: .color(AcousticGaugeStyle.trackColor),
            style: StrokeStyle(lineWidth: layout.trackWidth, lineCap: .round)
        )
    }

    /// 按 dB 分段采样渐变 stop，与 150°–390° 弧长严格等比例。
    private func drawGradientArc(context: inout GraphicsContext, layout: GaugeLayout) {
        let segmentCount = Int(AcousticGaugeStyle.displaySpan)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1))

            for index in 0..<segmentCount {
                let startDB = AcousticGaugeStyle.displayMinDecibel + Float(index)
                let endDB = startDB + 1
                let color = AcousticGaugeStyle.color(forDecibel: (startDB + endDB) * 0.5)
                let path = layout.arcPath(from: startDB, to: endDB)
                layer.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: layout.zoneWidth, lineCap: .butt, lineJoin: .round)
                )
            }
        }
    }

    private func drawTicks(context: inout GraphicsContext, layout: GaugeLayout) {
        var db = AcousticGaugeStyle.displayMinDecibel
        while db <= AcousticGaugeStyle.displayMaxDecibel + 0.1 {
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
                with: .color(isMajor ? AcousticGaugeStyle.tickMajorColor : AcousticGaugeStyle.tickMinorColor),
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
        let needleColor = AcousticGaugeStyle.color(forDecibel: db)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: needleColor.opacity(0.35), radius: 4, x: 0, y: 0))

            var needle = Path()
            needle.move(to: hub)
            needle.addLine(to: tip)
            layer.stroke(
                needle,
                with: .color(needleColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )

            let hubRadius: CGFloat = 5
            let hubRect = CGRect(
                x: hub.x - hubRadius,
                y: hub.y - hubRadius,
                width: hubRadius * 2,
                height: hubRadius * 2
            )
            layer.fill(Path(ellipseIn: hubRect), with: .color(needleColor))
            layer.fill(
                Path(ellipseIn: hubRect.insetBy(dx: 1.5, dy: 1.5)),
                with: .color(Color.black.opacity(0.88))
            )
        }
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

    /// 弧端（20 / 140 dB）位于 150° / 390°，sin = 0.5。
    private static let arcEndSine: CGFloat = 0.5
    private static let bottomPadding: CGFloat = 6

    init(size: CGSize) {
        let side = min(size.width, size.height)
        self.size = side
        self.radius = side * 0.48
        let arcBottom = radius * Self.arcEndSine
        self.center = CGPoint(
            x: size.width * 0.5,
            y: size.height - Self.bottomPadding - arcBottom
        )
    }

    func point(for db: Float, radius: CGFloat) -> CGPoint {
        let radians = AcousticGaugeStyle.angleDegrees(forDecibel: db) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    func arcPath(from startDB: Float, to endDB: Float) -> Path {
        var path = Path()
        let steps = max(2, Int((endDB - startDB) * 2))
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

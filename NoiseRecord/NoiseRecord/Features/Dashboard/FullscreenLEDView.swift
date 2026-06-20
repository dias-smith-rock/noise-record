import Combine
import SwiftUI
import UIKit

/// 横屏黑底 LED 硬件仪表风格全屏看板。
struct FullscreenLEDView: View {
    @Bindable var engine: NoiseMonitorEngine
    @Bindable var audioStateManager: AudioStateManager
    @Bindable var environment: AmbientEnvironmentProvider
    @Bindable private var appearance = AppAppearanceSettings.shared
    let mode: AcousticMeasurementMode
    let onClose: () -> Void

    @State private var now = Date()

    private var risk: NoiseRiskLevel {
        .from(db: engine.currentDB, highSensitivity: mode.isHighSensitivity)
    }

    private var theme: ModeVisualTheme { .theme(for: mode) }

    /// 辅助读数（时间、温湿度、波形）跟随主界面模式色。
    private var ledAccent: Color { theme.accent }

    /// 主分贝数字用同色系高亮，在黑底上更易辨认。
    private var decibelAccent: Color {
        switch mode {
        case .standard:
            Color(red: 0.55, green: 0.88, blue: 0.98)
        case .highSensitivity:
            Color(red: 1.0, green: 0.72, blue: 0.38)
        }
    }

    /// 量化到 0.1 dB，减少高频刷新时的视觉抖动。
    private var stabilizedDecibelText: String {
        let quantized = (engine.currentDB * 10).rounded() / 10
        return String(format: "%.1f", quantized)
    }

    var body: some View {
        let _ = appearance.temperatureUnitPreference

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topStatusBar
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                HStack(alignment: .center, spacing: 36) {
                    decibelPanel
                    rightMetricsPanel
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .frame(maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: activatePresentation)
        .onDisappear(perform: deactivatePresentation)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .background {
            LandscapeOrientationEnforcer()
                .frame(width: 0, height: 0)
        }
    }

    private enum LEDMetricTypography {
        static let digitSize: CGFloat = 34
        static let bodySize: CGFloat = 20
        static let iconSize: CGFloat = 24
    }

    private var topStatusBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 18) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.close)

                Image(systemName: batterySymbolName)
                    .font(.title2)
                    .foregroundStyle(ledAccent)

                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 10) {
                    statusFace(level: .quiet, isActive: risk == .quiet)
                    statusFace(level: .moderate, isActive: risk == .moderate)
                    statusFace(level: .loud, isActive: risk == .loud || risk == .dangerous)
                }
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ledDigitText(
                    clockTimeText,
                    size: LEDMetricTypography.digitSize,
                    color: ledAccent,
                    shadowRadius: 6
                )

                ledBodyText(
                    clockPeriodText,
                    size: LEDMetricTypography.bodySize,
                    color: ledAccent,
                    shadowRadius: 6
                )
            }
        }
    }

    private var decibelPanel: some View {
        GeometryReader { proxy in
            let fontSize = min(100, proxy.size.width * 0.34)

            VStack(alignment: .leading, spacing: 8) {
                ledDigitText(
                    stabilizedDecibelText,
                    size: fontSize,
                    color: decibelAccent,
                    shadowRadius: 8
                )
                .frame(width: proxy.size.width * 0.92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text(ledUnitLabel)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rightMetricsPanel: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)

            WaveformView(
                samples: engine.history,
                mode: mode,
                accentOverride: ledAccent,
                usesCardChrome: false
            )
            .equatable()
            .frame(width: 320, height: 60)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 24) {
                ledEnvironmentMetric(
                    symbol: "thermometer.medium",
                    value: environment.ledTemperatureValue,
                    unit: environment.ledTemperatureUnit
                )

                ledEnvironmentMetric(
                    symbol: "drop.fill",
                    value: environment.ledHumidityValue,
                    unit: environment.ledHumidityUnit
                )
            }
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .trailing)
    }

    private func ledDigitText(
        _ text: String,
        size: CGFloat,
        color: Color,
        shadowRadius: CGFloat = 4
    ) -> some View {
        Text(text)
            .font(SegmentedDigitalFont.font(size: size))
            .monospacedDigit()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.45), radius: shadowRadius)
    }

    private func ledBodyText(
        _ text: String,
        size: CGFloat,
        color: Color,
        shadowRadius: CGFloat = 4
    ) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.45), radius: shadowRadius)
    }

    private func ledEnvironmentMetric(symbol: String, value: String, unit: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: LEDMetricTypography.iconSize))
                .foregroundStyle(ledAccent)
                .padding(.bottom, 2)

            HStack(alignment: .bottom, spacing: 3) {
                ledDigitText(value, size: LEDMetricTypography.digitSize, color: ledAccent)

                if !unit.isEmpty {
                    ledBodyText(unit, size: LEDMetricTypography.bodySize, color: ledAccent.opacity(0.9))
                        .padding(.bottom, 2)
                }
            }
        }
    }

    private var ledUnitLabel: String {
        if mode.isHighSensitivity {
            mode.technicalBadge
        } else {
            "SLOW \(mode.technicalBadge)"
        }
    }

    private var clockTimeText: String {
        now.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private var clockPeriodText: String {
        let hour = Calendar.current.component(.hour, from: now)
        return hour < 12 ? "AM" : "PM"
    }

    private var batterySymbolName: String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return "battery.100" }

        switch level {
        case 0..<0.125: return "battery.0"
        case 0.125..<0.375: return "battery.25"
        case 0.375..<0.625: return "battery.50"
        case 0.625..<0.875: return "battery.75"
        default: return "battery.100"
        }
    }

    private func statusFace(level: NoiseRiskLevel, isActive: Bool) -> some View {
        let config = statusFaceConfig(for: level)
        return Image(systemName: config.symbol)
            .font(.title3)
            .foregroundStyle(config.tint)
            .opacity(isActive ? 1 : 0.28)
            .shadow(color: isActive ? config.tint.opacity(0.65) : .clear, radius: 4)
    }

    private func statusFaceConfig(for level: NoiseRiskLevel) -> (symbol: String, tint: Color) {
        switch level {
        case .quiet:
            ("face.smiling", .green)
        case .moderate:
            ("face.dashed", .yellow)
        case .loud, .dangerous:
            ("face.frowning", .red)
        }
    }

    private func activatePresentation() {
        SegmentedDigitalFont.diagnoseAndLog()
        UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        InterfaceOrientationLocker.enterLandscapeFullscreen()
        environment.startUpdating()
        startMonitoringIfNeeded()
    }

    private func deactivatePresentation() {
        UIApplication.shared.isIdleTimerDisabled = false
        InterfaceOrientationLocker.exitLandscapeFullscreen()
    }

    private func startMonitoringIfNeeded() {
        guard audioStateManager.appAudioState != .playing else { return }
        guard !engine.isMonitoring else {
            audioStateManager.noteMonitoringStarted()
            return
        }

        Task {
            await audioStateManager.manuallyResumeMonitoring()
        }
    }
}

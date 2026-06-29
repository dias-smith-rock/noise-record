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
    @State private var isEcoModeActive = false
    /// 夜间模式下限流展示的分贝值；后台 `engine.currentDB` 仍实时更新。
    @State private var throttledDecibel: Float = 0

    #if DEBUG
    private let ecoUIRefreshInterval: TimeInterval = 1
    #else
    private let ecoUIRefreshInterval: TimeInterval = 60
    #endif

    private var risk: NoiseRiskLevel {
        .from(db: engine.currentDB, highSensitivity: mode.isHighSensitivity)
    }

    private var theme: ModeVisualTheme { .theme(for: mode) }

    private var displayedDecibel: Float {
        isEcoModeActive ? throttledDecibel : engine.currentDB
    }

    /// 辅助读数（时间、温湿度、频谱）跟随主界面模式色。
    private var ledAccent: Color {
        isEcoModeActive ? theme.accent.opacity(0.16) : theme.accent
    }

    /// 主分贝数字用同色系高亮，在黑底上更易辨认。
    private var decibelAccent: Color {
        if isEcoModeActive {
            switch mode {
            case .standard:
                Color(red: 0.05, green: 0.2, blue: 0.05)
            case .highSensitivity:
                Color(red: 0.18, green: 0.07, blue: 0.02)
            }
        } else {
            switch mode {
            case .standard:
                Color(red: 0.55, green: 0.88, blue: 0.98)
            case .highSensitivity:
                Color(red: 1.0, green: 0.72, blue: 0.38)
            }
        }
    }

    private var secondaryTextColor: Color {
        isEcoModeActive ? Color.white.opacity(0.22) : Color.white.opacity(0.82)
    }

    private var iconShadowRadius: CGFloat { isEcoModeActive ? 0 : 6 }
    private var decibelShadowRadius: CGFloat { isEcoModeActive ? 0 : 8 }

    /// 量化到 0.1 dB，减少高频刷新时的视觉抖动。
    private var stabilizedDecibelText: String {
        let quantized = (displayedDecibel * 10).rounded() / 10
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
        .animation(.easeInOut(duration: 0.25), value: isEcoModeActive)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            throttledDecibel = engine.currentDB
            activatePresentation()
        }
        .onDisappear(perform: deactivatePresentation)
        .onChange(of: engine.currentDB) { _, newValue in
            if !isEcoModeActive {
                throttledDecibel = newValue
            }
        }
        .onChange(of: isEcoModeActive) { _, isEco in
            if !isEco {
                throttledDecibel = engine.currentDB
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            guard !isEcoModeActive else { return }
            now = date
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            guard isEcoModeActive else { return }
            now = date
        }
        .onReceive(Timer.publish(every: ecoUIRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
            guard isEcoModeActive else { return }
            throttledDecibel = engine.currentDB
        }
        .background {
            LandscapeOrientationEnforcer()
                .frame(width: 0, height: 0)
        }
    }

    private var topStatusBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 18) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isEcoModeActive ? Color.white.opacity(0.28) : Color.white.opacity(0.72)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.close)

                Image(systemName: batterySymbolName)
                    .font(.title2)
                    .foregroundStyle(ledAccent)

                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(isEcoModeActive ? Color.white.opacity(0.2) : Color.white.opacity(0.85))

                HStack(spacing: 10) {
                    statusFace(level: .quiet, isActive: risk == .quiet)
                    statusFace(level: .moderate, isActive: risk == .moderate)
                    statusFace(level: .loud, isActive: risk == .loud || risk == .dangerous)
                }
            }

            Spacer()

            HStack(alignment: .center, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ledDigitText(
                        clockTimeText,
                        size: LEDMetricTypography.digitSize,
                        color: ledAccent,
                        shadowRadius: iconShadowRadius
                    )

                    ledBodyText(
                        clockPeriodText,
                        size: LEDMetricTypography.bodySize,
                        color: ledAccent,
                        shadowRadius: iconShadowRadius
                    )
                }

                ecoModeToggleButton
            }
        }
    }

    private var ecoModeToggleButton: some View {
        Button(action: toggleEcoMode) {
            Label("ECO", systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isEcoModeActive
                        ? Color(red: 0.05, green: 0.2, blue: 0.05)
                        : Color.white.opacity(0.72)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(
                            isEcoModeActive
                                ? Color.white.opacity(0.08)
                                : Color.white.opacity(0.1)
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isEcoModeActive
                                ? Color(red: 0.05, green: 0.2, blue: 0.05).opacity(0.6)
                                : Color.white.opacity(0.22),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEcoModeActive ? "Eco night mode on" : "Eco night mode off")
        .accessibilityAddTraits(isEcoModeActive ? [.isSelected] : [])
    }

    private enum LEDMetricTypography {
        static let digitSize: CGFloat = 34
        static let bodySize: CGFloat = 20
        static let iconSize: CGFloat = 24
    }

    private var decibelPanel: some View {
        GeometryReader { proxy in
            let fontSize = min(100, proxy.size.width * 0.34)

            VStack(alignment: .leading, spacing: 8) {
                ledDigitText(
                    stabilizedDecibelText,
                    size: fontSize,
                    color: decibelAccent,
                    shadowRadius: decibelShadowRadius
                )
                .frame(width: proxy.size.width * 0.92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text(ledUnitLabel)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(secondaryTextColor)
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var spectrumSection: some View {
        if isEcoModeActive {
            ecoFrozenSpectrumLine
        } else {
            FullscreenLEDSpectrumStrip(
                spectrum: engine.latestSpectrum,
                accent: ledAccent
            )
            .equatable()
        }
    }

    private var ecoFrozenSpectrumLine: some View {
        Rectangle()
            .fill(ledAccent.opacity(0.35))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var rightMetricsPanel: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)

            spectrumSection
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
            .shadow(color: shadowRadius > 0 ? color.opacity(0.45) : .clear, radius: shadowRadius)
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
            .shadow(color: shadowRadius > 0 ? color.opacity(0.45) : .clear, radius: shadowRadius)
    }

    private func ledEnvironmentMetric(symbol: String, value: String, unit: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: LEDMetricTypography.iconSize))
                .foregroundStyle(ledAccent)
                .padding(.bottom, 2)

            HStack(alignment: .bottom, spacing: 3) {
                ledDigitText(
                    value,
                    size: LEDMetricTypography.digitSize,
                    color: ledAccent,
                    shadowRadius: iconShadowRadius
                )

                if !unit.isEmpty {
                    ledBodyText(
                        unit,
                        size: LEDMetricTypography.bodySize,
                        color: isEcoModeActive ? ledAccent : ledAccent.opacity(0.9),
                        shadowRadius: iconShadowRadius
                    )
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
        let tint = isEcoModeActive ? config.tint.opacity(isActive ? 0.35 : 0.12) : config.tint
        return Image(systemName: config.symbol)
            .font(.title3)
            .foregroundStyle(tint)
            .opacity(isActive ? 1 : 0.28)
            .shadow(color: isActive && !isEcoModeActive ? config.tint.opacity(0.65) : .clear, radius: 4)
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

    private func toggleEcoMode() {
        isEcoModeActive.toggle()
        throttledDecibel = engine.currentDB
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

// MARK: - Compact LED spectrum strip

private struct FullscreenLEDSpectrumStrip: View, Equatable {
    let spectrum: FFTSpectrum?
    let accent: Color

    static func == (lhs: FullscreenLEDSpectrumStrip, rhs: FullscreenLEDSpectrumStrip) -> Bool {
        lhs.spectrum == rhs.spectrum
    }

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let plotRect = CGRect(origin: .zero, size: size)
            let coords = SpectrumPlotCoordinateSystem(plotRect: plotRect)

            guard let spectrum, !spectrum.decibels.isEmpty else { return }

            let path = SpectrumPathBuilder(
                coords: coords,
                sampleRate: spectrum.sampleRate,
                fftSize: spectrum.fftSize
            ).buildPath(decibels: spectrum.decibels)

            context.stroke(
                path,
                with: .color(accent),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .drawingGroup()
    }
}

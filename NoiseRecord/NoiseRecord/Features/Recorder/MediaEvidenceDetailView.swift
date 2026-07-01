import AVKit
import SwiftData
import SwiftUI

enum MediaDetailTab: String, CaseIterable, Identifiable {
    case waveform
    case levels
    case exposure

    var id: String { rawValue }
}

struct MediaEvidenceDetailView: View {
    enum MediaKind {
        case audio(RecordingSession)
        case video(VideoEvidenceSession)
    }

    let kind: MediaKind
    @Bindable var audioStateManager: AudioStateManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguageRevision) private var appLanguageRevision

    @State private var model = MediaEvidenceDetailModel()
    @State private var selectedTab: MediaDetailTab = .waveform
    @State private var notes = ""
    @State private var notesSaveTask: Task<Void, Never>?
    @State private var displayTitle = ""
    @State private var displaySubtitle: String?
    @State private var playbackError: String?
    @State private var waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB

    private var measurementMode: AcousticMeasurementMode {
        AcousticMeasurementMode(isHighSensitivity: DeviceCalibrationStore.isHighSensitivityMode)
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
    }

    private var fileURL: URL {
        switch kind {
        case .audio(let session): session.fileURL
        case .video(let session): session.fileURL
        }
    }

    private var startedAt: Date {
        switch kind {
        case .audio(let session): session.startedAt
        case .video(let session): session.startedAt
        }
    }

    private var sessionDuration: TimeInterval {
        switch kind {
        case .audio(let session): session.duration
        case .video(let session): session.duration
        }
    }

    private var fallbackPeak: Float {
        switch kind {
        case .audio(let session): session.peakDB
        case .video(let session): session.peakDB
        }
    }

    private var fallbackAverage: Float {
        switch kind {
        case .audio(let session): session.averageDB
        case .video(let session): session.averageDB
        }
    }

    private var metrics: NoiseTimelineMetrics {
        NoiseTimelineMetrics.compute(
            from: model.timeline,
            sessionDuration: sessionDuration,
            fallbackPeak: fallbackPeak,
            fallbackAverage: fallbackAverage
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                tabPicker
                tabContent

                if let coordinate = locationCoordinate {
                    VStack(alignment: .leading, spacing: 10) {
                        ProSectionHeader(title: L10n.mediaDetailLocationTitle, theme: theme)
                        EvidenceLocationCard(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            addressLine: displayTitle,
                            secondaryLine: displaySubtitle,
                            theme: theme
                        )
                    }
                }

                if selectedTab != .exposure {
                    notesSection
                    meterConfigurationSection
                    exposureConfigurationSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    SharePresenter.present(items: [fileURL])
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.share)
            }
        }
        .observesAppLanguage()
        .onAppear(perform: bootstrap)
        .onDisappear {
            model.cleanup()
            audioStateManager.handlePlaybackFinished()
        }
        .onReceive(NotificationCenter.default.publisher(for: NoiseReferenceLimits.didChangeNotification)) { _ in
            waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB
        }
        .alert(L10n.filesPlaybackErrorTitle, isPresented: Binding(
            get: { playbackError != nil },
            set: { if !$0 { playbackError = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { playbackError = nil }
        } message: {
            Text(playbackError ?? "")
        }
    }

    private var locationCoordinate: (latitude: Double, longitude: Double)? {
        switch kind {
        case .audio(let session):
            guard let latitude = session.latitude, let longitude = session.longitude else { return nil }
            return (latitude, longitude)
        case .video(let session):
            guard let latitude = session.latitude, let longitude = session.longitude else { return nil }
            return (latitude, longitude)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle.isEmpty ? fileURL.lastPathComponent : displayTitle)
                .font(.title2.bold())
            Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabPicker: some View {
        Picker(L10n.mediaDetailTabPicker, selection: $selectedTab) {
            Text(L10n.mediaDetailTabWaveform).tag(MediaDetailTab.waveform)
            Text(L10n.mediaDetailTabLevels).tag(MediaDetailTab.levels)
            Text(L10n.mediaDetailTabExposure).tag(MediaDetailTab.exposure)
        }
        .pickerStyle(.segmented)
        .id(appLanguageRevision)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .waveform:
            waveformTab
        case .levels:
            levelsTab
        case .exposure:
            exposureTab
        }
    }

    private var waveformTab: some View {
        VStack(spacing: 16) {
            if model.isLoadingTimeline {
                ProgressView(L10n.mediaDetailAnalyzingWaveform)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if model.waveformSamples.isEmpty {
                ContentUnavailableView(
                    L10n.mediaDetailNoWaveformTitle,
                    systemImage: "waveform",
                    description: Text(model.timelineError ?? L10n.mediaDetailNoWaveformMessage)
                )
                .frame(minHeight: 160)
            } else {
                EvidenceBarWaveformView(
                    samples: model.waveformSamples,
                    duration: max(model.duration, sessionDuration),
                    currentTime: model.currentTime,
                    mode: measurementMode,
                    referenceLimitDB: waveformReferenceLimitDB,
                    onSeek: { model.seek(to: $0) }
                )
            }

            if case .video = kind, let player = model.videoPlayerBinding() {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                model.togglePlayback()
            } label: {
                Label(
                    model.isPlaying ? L10n.mediaDetailPause : L10n.mediaDetailPlay,
                    systemImage: model.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(model.isLoadingTimeline)
        }
    }

    private var levelsTab: some View {
        VStack(spacing: 20) {
            exposureMetricsSection
            soundLevelsSection
        }
    }

    private var exposureTab: some View {
        VStack(spacing: 20) {
            notesSection
            meterConfigurationSection
            exposureConfigurationSection
        }
    }

    private var exposureMetricsSection: some View {
        EvidenceMetricSection(title: L10n.mediaDetailExposureSection, theme: theme) {
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailDuration,
                    value: EvidenceTimeFormatting.compactDuration(metrics.duration),
                    infoText: L10n.mediaDetailInfoDuration,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailDose,
                    value: String(format: "%.2f%%", metrics.dosePercent),
                    infoText: L10n.mediaDetailInfoDose,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailProjectedDose,
                    value: String(format: "%.2f%%", metrics.projectedDosePercent),
                    infoText: L10n.mediaDetailInfoProjectedDose,
                    theme: theme
                )
            }
            EvidenceMetricRow(
                title: L10n.mediaDetailTimeAveragedExposure,
                value: formattedDecibel(metrics.timeAveragedDB, weighting: metrics.weighting),
                infoText: L10n.mediaDetailInfoTimeAveraged,
                theme: theme
            )
        }
    }

    private var soundLevelsSection: some View {
        EvidenceMetricSection(title: L10n.mediaDetailSoundLevelsSection, theme: theme) {
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailPeak,
                    subtitle: "LCpeak",
                    value: formattedDecibel(metrics.peakDB, weighting: "dBC"),
                    infoText: L10n.mediaDetailInfoPeak,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailMaximum,
                    subtitle: "LASmax",
                    value: formattedDecibel(metrics.maximumDB, weighting: metrics.weighting),
                    infoText: L10n.mediaDetailInfoMaximum,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceMetricRow(
                    title: L10n.mediaDetailTimeAveraged,
                    subtitle: "LASavg",
                    value: formattedDecibel(metrics.timeAveragedDB, weighting: metrics.weighting),
                    infoText: L10n.mediaDetailInfoTimeAveraged,
                    theme: theme
                )
            }
            EvidenceMetricRow(
                title: L10n.mediaDetailLAeq,
                subtitle: "LAeq",
                value: formattedDecibel(metrics.laeqDB, weighting: metrics.weighting),
                infoText: L10n.mediaDetailInfoLAeq,
                theme: theme
            )
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProSectionHeader(title: L10n.mediaDetailNotesTitle, theme: theme)
            EvidenceNotesEditor(notes: $notes, theme: theme, onCommit: scheduleNotesSave)
        }
    }

    private var meterConfigurationSection: some View {
        EvidenceMetricSection(title: L10n.mediaDetailMeterConfiguration, theme: theme) {
            metricDividerWrapped {
                EvidenceConfigRow(
                    title: L10n.mediaDetailTimeWeighting,
                    value: L10n.mediaDetailTimeWeightingSlow,
                    infoText: L10n.mediaDetailInfoTimeWeighting,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceConfigRow(
                    title: L10n.mediaDetailFrequencyWeighting,
                    value: DeviceCalibrationStore.weightingType.rawValue,
                    infoText: L10n.mediaDetailInfoFrequencyWeighting,
                    theme: theme
                )
            }
            EvidenceConfigRow(
                title: L10n.mediaDetailPeakFrequencyWeighting,
                value: ExposureStandards.peakWeighting.rawValue,
                infoText: L10n.mediaDetailInfoPeakWeighting,
                theme: theme
            )
        }
    }

    private var exposureConfigurationSection: some View {
        EvidenceMetricSection(title: L10n.mediaDetailExposureConfiguration, theme: theme) {
            metricDividerWrapped {
                EvidenceConfigRow(
                    title: L10n.mediaDetailCriterionDuration,
                    value: L10n.mediaDetailCriterionDurationValue,
                    infoText: L10n.mediaDetailInfoCriterionDuration,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceConfigRow(
                    title: L10n.mediaDetailCriterionLevel,
                    value: L10n.mediaDetailCriterionLevelValue,
                    infoText: L10n.mediaDetailInfoCriterionLevel,
                    theme: theme
                )
            }
            metricDividerWrapped {
                EvidenceConfigRow(
                    title: L10n.mediaDetailThresholdLevel,
                    value: L10n.mediaDetailThresholdLevelValue,
                    infoText: L10n.mediaDetailInfoThresholdLevel,
                    theme: theme
                )
            }
            EvidenceConfigRow(
                title: L10n.mediaDetailExchangeRate,
                value: L10n.mediaDetailExchangeRateValue,
                infoText: L10n.mediaDetailInfoExchangeRate,
                theme: theme
            )
        }
    }

    @ViewBuilder
    private func metricDividerWrapped<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
            Divider()
        }
    }

    private func formattedDecibel(_ value: Float?, weighting: String) -> String {
        guard let value else { return L10n.mediaDetailNotAvailable }
        return String(format: "%.1f %@", value, weighting)
    }

    private func bootstrap() {
        waveformReferenceLimitDB = NoiseReferenceLimits.residentialNightDB

        switch kind {
        case .audio(let session):
            notes = session.notes
            displayTitle = session.fileName
            markAsRead(session)
            resolveDisplayAddressIfNeeded()
        case .video(let session):
            notes = session.notes
            displayTitle = session.fileName
            markAsRead(session)
            resolveDisplayAddressIfNeeded()
        }

        guard fileExists else {
            playbackError = missingFileMessage
            return
        }

        do {
            try audioStateManager.prepareAndStartPlayback()
            try model.configurePlayback(
                url: fileURL,
                isVideo: isVideo,
                fallbackDuration: sessionDuration
            )
        } catch {
            playbackError = error.localizedDescription
            return
        }

        Task {
            await model.loadTimeline(from: fileURL, isVideo: isVideo)
        }
    }

    private var isVideo: Bool {
        if case .video = kind { return true }
        return false
    }

    private var fileExists: Bool {
        switch kind {
        case .audio(let session): session.fileExists
        case .video(let session): session.fileExists
        }
    }

    private var missingFileMessage: String {
        switch kind {
        case .audio(let session): L10n.filesAudioNotFound(session.fileName)
        case .video(let session): L10n.filesVideoNotFound(session.fileName)
        }
    }

    private func resolveDisplayAddressIfNeeded() {
        guard let coordinate = locationCoordinate else { return }
        Task {
            let resolved = await EvidenceGeocoder.resolveAddress(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            displayTitle = resolved.title
            displaySubtitle = resolved.subtitle
        }
    }

    private func markAsRead(_ session: RecordingSession) {
        guard session.isNew else { return }
        session.isNew = false
        try? modelContext.save()
    }

    private func markAsRead(_ session: VideoEvidenceSession) {
        guard session.isNew else { return }
        session.isNew = false
        try? modelContext.save()
    }

    private func scheduleNotesSave() {
        notesSaveTask?.cancel()
        notesSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persistNotes()
            }
        }
    }

    private func persistNotes() {
        switch kind {
        case .audio(let session):
            session.notes = notes
        case .video(let session):
            session.notes = notes
        }
        try? modelContext.save()
    }
}

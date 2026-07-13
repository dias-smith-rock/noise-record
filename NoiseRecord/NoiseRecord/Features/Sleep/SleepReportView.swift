import PDFKit
import SwiftData
import SwiftUI
import UIKit

struct SleepReportView: View {
    let sessionID: UUID
    var showsHistoryButton: Bool = true
    var themeMeasurementMode: AcousticMeasurementMode? = nil
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Bindable private var appearance = AppAppearanceSettings.shared
    @Bindable private var subscriptions = SubscriptionManager.shared
    @State private var session: SleepNoiseSession?
    @State private var showHistory = false
    @State private var csvExportErrorMessage: String?
    @State private var showPDFFormatPicker = false
    @State private var pendingPDFSession: SleepNoiseSession?
    @State private var embeddedPDFURL: URL?
    @State private var embeddedPDFLoadFailed = false
    @State private var embeddedPDFCurrentPage = 1
    @State private var embeddedPDFTotalPages = 0
    @State private var embeddedPDFFormat: SleepForensicReportFormat = .legacyOvernight
    @State private var showPDFShareSheet = false

    private var measurementMode: AcousticMeasurementMode {
        if let session, session.isHighSensitivitySession {
            return .highSensitivity
        }
        return .standard
    }

    private var theme: ModeVisualTheme {
        .theme(for: themeMeasurementMode ?? measurementMode)
    }

    private var isPDFPreviewBlurred: Bool {
        SleepPDFPreviewAccessStore.shouldBlurPreview(isPremium: subscriptions.canAccessSleepExport)
    }

    var body: some View {
        let _ = appearance.accentRefreshID

        NavigationStack {
            ScrollView {
                if let session {
                    VStack(alignment: .leading, spacing: 20) {
                        gradeHeader(session)
                        summarySection(session)
                        anomaliesSection(session)
                        disclaimer
                        actionButtons(session)
                        embeddedPDFPreviewSection
                    }
                    .padding()
                } else {
                    ProgressView()
                        .tint(theme.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsPDFUnlockBar {
                    pdfUnlockBar
                }
            }
            .navigationTitle(L10n.sleepReportTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.close, action: onDismiss)
                        .foregroundStyle(theme.accent)
                }
            }
            .navigationDestination(isPresented: $showHistory) {
                SleepHistoryView(measurementMode: measurementMode)
            }
            .sheet(isPresented: $showPDFShareSheet) {
                if let embeddedPDFURL {
                    ShareSheet(items: [embeddedPDFURL])
                }
            }
            .confirmationDialog(
                L10n.sleepReportExportPDF,
                isPresented: $showPDFFormatPicker,
                titleVisibility: .visible
            ) {
                Button(SleepForensicReportFormat.legacyOvernight.title) {
                    if let pendingPDFSession {
                        AppTelemetry.logProductEvent(
                            "sleep_pdf_format_selected",
                            parameters: ["format": SleepForensicReportFormat.legacyOvernight.rawValue]
                        )
                        exportPDF(pendingPDFSession, format: .legacyOvernight)
                    }
                }
                Button(SleepForensicReportFormat.nighttimeEnvironmental.title) {
                    if let pendingPDFSession {
                        AppTelemetry.logProductEvent(
                            "sleep_pdf_format_selected",
                            parameters: ["format": SleepForensicReportFormat.nighttimeEnvironmental.rawValue]
                        )
                        exportPDF(pendingPDFSession, format: .nighttimeEnvironmental)
                    }
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingPDFSession = nil
                }
            }
        }
        .proTabBackground(theme: theme)
        .preferredColorScheme(appearance.colorSchemePreference.colorScheme)
        .tint(theme.accent)
        .observesAppLanguage()
        .paywallPresenter()
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { csvExportErrorMessage != nil },
            set: { if !$0 { csvExportErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { csvExportErrorMessage = nil }
        } message: {
            Text(csvExportErrorMessage ?? "")
        }
        .task(id: sessionID) {
            loadSession()
        }
        .task(id: session?.id) {
            guard let session else { return }
            await refreshEmbeddedPDF(session, format: embeddedPDFFormat)
        }
        .onDisappear {
            guard !subscriptions.canAccessSleepExport else { return }
            guard !SleepPDFPreviewAccessStore.hasConsumedGlobalFreePreview else { return }
            SleepPDFPreviewAccessStore.markGlobalFreePreviewConsumed()
        }
    }

    private var showsPDFUnlockBar: Bool {
        session != nil && isPDFPreviewBlurred
    }

    private var pdfUnlockBar: some View {
        PDFPreviewUnlockBar(theme: theme) {
            AppTelemetry.logProductEvent("sleep_pdf_unlock_tap")
            PaywallPresenter.shared.present(context: .sleepExport)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.bar)
    }

    @ViewBuilder
    private func gradeHeader(_ session: SleepNoiseSession) -> some View {
        ProCard(theme: theme) {
            HStack(spacing: 16) {
                Text(session.silenceGrade.rawValue)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.silenceGrade.title)
                        .font(.title3.bold())
                    Text(L10n.sleepReportOverallLevel(String(format: "%.0f", session.overallLeq)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(L10n.sleepReportFloorLevel(String(format: "%.0f", session.noiseFloorDB)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ session: SleepNoiseSession) -> some View {
        if let summary = session.reportSummary {
            Text(summary)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func anomaliesSection(_ session: SleepNoiseSession) -> some View {
        if !session.anomalies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ProSectionHeader(
                    title: L10n.sleepReportAnomaliesTitle,
                    theme: theme
                )
                ForEach(session.anomalies.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { anomaly in
                    anomalyRow(anomaly)
                }
            }
        }
    }

    private func anomalyRow(_ anomaly: SleepAnomalyEvent) -> some View {
        ProCard(theme: theme) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedTime(anomaly.timestamp))
                        .font(.subheadline.weight(.semibold))
                    Text(impactText(for: anomaly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f dB", anomaly.peakDB))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private var disclaimer: some View {
        Text(L10n.sleepReportDisclaimer)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func actionButtons(_ session: SleepNoiseSession) -> some View {
        HStack(spacing: 8) {
            if showsHistoryButton {
                themedActionButton(
                    title: L10n.sleepReportViewHistory,
                    systemImage: "chart.line.uptrend.xyaxis"
                ) {
                    AppTelemetry.logProductEvent(
                        "sleep_history_open",
                        parameters: ["gated": "false"]
                    )
                    showHistory = true
                }
            }

            themedActionButton(
                title: L10n.sleepReportExport,
                systemImage: "square.and.arrow.up"
            ) {
                AppTelemetry.logProductEvent("sleep_export_csv_tap")
                exportCSV(session)
            }

            themedActionButton(
                title: L10n.sleepReportExportPDF,
                systemImage: "doc.richtext"
            ) {
                AppTelemetry.logProductEvent("sleep_export_pdf_tap")
                guard SubscriptionManager.shared.canAccessSleepExport else {
                    PaywallPresenter.shared.present(context: .sleepExport)
                    return
                }
                pendingPDFSession = session
                showPDFFormatPicker = true
            }
        }
    }

    @ViewBuilder
    private var embeddedPDFPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(embeddedPDFFormat.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent.opacity(0.85))
                    .lineLimit(2)
                Spacer()
                if subscriptions.canAccessSleepExport,
                   embeddedPDFURL != nil, !embeddedPDFLoadFailed {
                    Button {
                        AppTelemetry.logProductEvent(
                            "sleep_pdf_share_tap",
                            parameters: ["format": embeddedPDFFormat.rawValue]
                        )
                        showPDFShareSheet = true
                    } label: {
                        Label(L10n.share, systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)
                }
            }

            Group {
                if embeddedPDFLoadFailed {
                    ContentUnavailableView(
                        L10n.sleepReportExportPDF,
                        systemImage: "doc.richtext",
                        description: Text(L10n.errorTitle)
                    )
                    .frame(height: 160)
                } else if let embeddedPDFURL {
                    PDFPagesStackView(
                        url: embeddedPDFURL,
                        reportFormat: embeddedPDFFormat,
                        isPreviewBlurred: isPDFPreviewBlurred,
                        loadFailed: $embeddedPDFLoadFailed,
                        currentPage: $embeddedPDFCurrentPage,
                        totalPages: $embeddedPDFTotalPages
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .tint(theme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .background(theme.cardTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )

            if !embeddedPDFLoadFailed, embeddedPDFTotalPages > 0 {
                Text("\(embeddedPDFCurrentPage) / \(embeddedPDFTotalPages)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func themedActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .foregroundStyle(theme.accent)
            .background(theme.cardTint)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.surfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func loadSession() {
        let targetID = sessionID
        let descriptor = FetchDescriptor<SleepNoiseSession>(
            predicate: #Predicate { $0.id == targetID }
        )
        session = try? modelContext.fetch(descriptor).first
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.resolvedLocale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func impactText(for anomaly: SleepAnomalyEvent) -> String {
        switch anomaly.impactHint {
        case .deepSleep:
            L10n.sleepReportImpactDeepSleep
        case .lightSleep, .none:
            L10n.sleepReportImpactLightSleep
        }
    }

    private func exportCSV(_ session: SleepNoiseSession) {
        guard SubscriptionManager.shared.canAccessSleepExport else {
            PaywallPresenter.shared.present(context: .sleepExport)
            return
        }
        let samples = SleepMeasurementPersistence.samples(
            for: session.id,
            in: modelContext
        )
        let rows = samples.map {
            MeasurementCSVRow(
                timestamp: $0.timestamp,
                dbCurrent: $0.dbCurrent,
                dbMax: $0.dbMax,
                dbMin: $0.dbMin,
                dbAvg: $0.dbAvg,
                leq: $0.leq,
                weighting: $0.weighting,
                noiseType: $0.noiseType
            )
        }
        guard let url = CSVExporter.exportSleepSessionLog(
            session: session,
            rows: rows
        ) else {
            csvExportErrorMessage = L10n.dashboardExportCSVFailed
            return
        }
        SharePresenter.present(items: [url])
    }

    private func refreshEmbeddedPDF(_ session: SleepNoiseSession, format: SleepForensicReportFormat) async {
        embeddedPDFFormat = format
        embeddedPDFLoadFailed = false
        embeddedPDFCurrentPage = 1
        embeddedPDFTotalPages = 0

        let samples = SleepMeasurementPersistence.samples(
            for: session.id,
            in: modelContext
        )
        let sleepID = session.id
        let recordingDescriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { $0.sleepSessionID == sleepID }
        )
        let recordings = (try? modelContext.fetch(recordingDescriptor)) ?? []
        let payload = await SleepForensicPDFExporter.makePayload(
            session: session,
            samples: samples,
            recordings: recordings
        )

        let url: URL?
        switch format {
        case .legacyOvernight:
            url = SleepForensicPDFExporter.export(payload: payload)
        case .nighttimeEnvironmental:
            url = SleepNEMRPDFExporter.export(payload: payload)
        }

        embeddedPDFURL = url
        embeddedPDFLoadFailed = url == nil
    }

    private func exportPDF(_ session: SleepNoiseSession, format: SleepForensicReportFormat) {
        guard SubscriptionManager.shared.canAccessSleepExport else {
            PaywallPresenter.shared.present(context: .sleepExport)
            return
        }
        pendingPDFSession = nil
        Task {
            await refreshEmbeddedPDF(session, format: format)
        }
    }
}

private struct PageVisibilityEntry: Equatable {
    let pageIndex: Int
    let visibleArea: CGFloat
}

private struct PageVisibilityPreference: PreferenceKey {
    static var defaultValue: [PageVisibilityEntry] = []

    static func reduce(value: inout [PageVisibilityEntry], nextValue: () -> [PageVisibilityEntry]) {
        value.append(contentsOf: nextValue())
    }
}

private enum PDFPageImageRenderer {
    static func render(page: PDFPage, targetWidth: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0, targetWidth > 0 else { return nil }

        let scale = targetWidth / bounds.width
        let targetHeight = bounds.height * scale
        let size = CGSize(width: targetWidth, height: targetHeight)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: targetHeight)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

private struct PDFPagesStackView: View {
    let url: URL
    let reportFormat: SleepForensicReportFormat
    let isPreviewBlurred: Bool
    @Binding var loadFailed: Bool
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    @State private var pageImages: [UIImage] = []
    @State private var pageClearTopRatios: [CGFloat] = []
    @State private var renderWidth: CGFloat = 0
    @State private var zoomScale: CGFloat = 1
    @State private var steadyZoomScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 8) {
            if pageImages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    pageStack
                        .scaleEffect(zoomScale, anchor: .top)
                        .frame(width: renderWidth * zoomScale, alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .simultaneousGesture(magnificationGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        zoomScale = 1
                        steadyZoomScale = 1
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateRenderWidth(geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        updateRenderWidth(newWidth)
                    }
            }
        }
        .onPreferenceChange(PageVisibilityPreference.self) { entries in
            guard let best = entries.max(by: { $0.visibleArea < $1.visibleArea }),
                  best.visibleArea > 1 else { return }
            currentPage = best.pageIndex + 1
        }
        .task(id: "\(url.absoluteString)-\(renderWidth)-\(isPreviewBlurred)-\(reportFormat.rawValue)") {
            zoomScale = 1
            steadyZoomScale = 1
            await loadPages()
        }
    }

    private var pageStack: some View {
        VStack(spacing: 8) {
            ForEach(Array(pageImages.enumerated()), id: \.offset) { index, image in
                BlurredPDFPageImage(
                    image: image,
                    clearTopRatio: pageClearTopRatios.indices.contains(index)
                        ? pageClearTopRatios[index]
                        : 1
                )
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .background {
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .global)
                        let visible = frame.intersection(UIScreen.main.bounds)
                        let area = max(0, visible.width) * max(0, visible.height)
                        Color.clear.preference(
                            key: PageVisibilityPreference.self,
                            value: [PageVisibilityEntry(pageIndex: index, visibleArea: area)]
                        )
                    }
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = steadyZoomScale * value
                zoomScale = min(max(proposed, 1), 3)
            }
            .onEnded { _ in
                steadyZoomScale = zoomScale
            }
    }

    private func updateRenderWidth(_ width: CGFloat) {
        guard width > 0, abs(width - renderWidth) > 0.5 else { return }
        renderWidth = width
    }

    @MainActor
    private func loadPages() async {
        guard renderWidth > 0 else { return }

        let document: PDFDocument?
        if let data = try? Data(contentsOf: url) {
            document = PDFDocument(data: data)
        } else {
            document = PDFDocument(url: url)
        }

        guard let document, document.pageCount > 0 else {
            loadFailed = true
            pageImages = []
            pageClearTopRatios = []
            totalPages = 0
            return
        }

        var images: [UIImage] = []
        var clearTopRatios: [CGFloat] = []
        images.reserveCapacity(document.pageCount)
        clearTopRatios.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let image = PDFPageImageRenderer.render(page: page, targetWidth: renderWidth) else {
                continue
            }
            images.append(image)
            clearTopRatios.append(
                PDFPreviewBlurGate.clearTopRatio(
                    forPageIndex: index,
                    page: page,
                    format: reportFormat,
                    isPreviewBlurred: isPreviewBlurred
                )
            )
        }

        guard !images.isEmpty else {
            loadFailed = true
            pageImages = []
            pageClearTopRatios = []
            totalPages = 0
            return
        }

        pageImages = images
        pageClearTopRatios = clearTopRatios
        totalPages = images.count
        currentPage = 1
        loadFailed = false
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

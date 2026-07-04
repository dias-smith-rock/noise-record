import PDFKit
import SwiftData
import SwiftUI
import UIKit

struct SleepReportView: View {
    let sessionID: UUID
    var showsHistoryButton: Bool = true
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Bindable private var appearance = AppAppearanceSettings.shared
    @State private var session: SleepNoiseSession?
    @State private var showHistory = false
    @State private var csvShareURL: URL?
    @State private var showCSVShare = false
    @State private var showPDFFormatPicker = false
    @State private var pendingPDFSession: SleepNoiseSession?
    @State private var embeddedPDFURL: URL?
    @State private var embeddedPDFLoadFailed = false
    @State private var embeddedPDFCurrentPage = 1
    @State private var embeddedPDFTotalPages = 0
    @State private var embeddedPDFFormat: SleepForensicReportFormat = .nighttimeEnvironmental
    @State private var showPDFShareSheet = false

    private var measurementMode: AcousticMeasurementMode {
        if let session, session.isHighSensitivitySession {
            return .highSensitivity
        }
        return .standard
    }

    private var theme: ModeVisualTheme {
        .theme(for: measurementMode)
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
            .background(Color(.systemGroupedBackground))
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
            .sheet(isPresented: $showCSVShare) {
                if let csvShareURL {
                    ShareSheet(items: [csvShareURL])
                }
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
                        exportPDF(pendingPDFSession, format: .legacyOvernight)
                    }
                }
                Button(SleepForensicReportFormat.nighttimeEnvironmental.title) {
                    if let pendingPDFSession {
                        exportPDF(pendingPDFSession, format: .nighttimeEnvironmental)
                    }
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingPDFSession = nil
                }
            }
        }
        .tint(theme.accent)
        .observesAppLanguage()
        .paywallPresenter()
        .task(id: sessionID) {
            loadSession()
        }
        .task(id: session?.id) {
            guard let session else { return }
            refreshEmbeddedPDF(session, format: embeddedPDFFormat)
        }
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
                Text(L10n.sleepReportAnomaliesTitle)
                    .font(.headline)
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
        VStack(spacing: 12) {
            if showsHistoryButton {
                themedActionButton(
                    title: L10n.sleepReportViewHistory,
                    systemImage: "chart.line.uptrend.xyaxis"
                ) {
                    if SubscriptionManager.shared.canAccessSleepHistory {
                        showHistory = true
                    } else {
                        PaywallPresenter.shared.present(context: .sleepHistory)
                    }
                }
            }

            themedActionButton(
                title: L10n.sleepReportExport,
                systemImage: "square.and.arrow.up"
            ) {
                exportCSV(session)
            }

            themedActionButton(
                title: L10n.sleepReportExportPDF,
                systemImage: "doc.richtext"
            ) {
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
        if SubscriptionManager.shared.canAccessSleepExport {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(embeddedPDFFormat.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    if embeddedPDFURL != nil, !embeddedPDFLoadFailed {
                        Button {
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
                    } else if let embeddedPDFURL {
                        PDFKitPreviewView(
                            url: embeddedPDFURL,
                            loadFailed: $embeddedPDFLoadFailed,
                            currentPage: $embeddedPDFCurrentPage,
                            totalPages: $embeddedPDFTotalPages
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tint(theme.accent)
                    }
                }
                .frame(height: 420)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
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
    }

    private func themedActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
        csvShareURL = CSVExporter.exportSleepSessionLog(
            session: session,
            rows: rows
        )
        showCSVShare = csvShareURL != nil
    }

    private func refreshEmbeddedPDF(_ session: SleepNoiseSession, format: SleepForensicReportFormat) {
        guard SubscriptionManager.shared.canAccessSleepExport else {
            embeddedPDFURL = nil
            embeddedPDFLoadFailed = false
            embeddedPDFTotalPages = 0
            return
        }

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
        let payload = SleepForensicPDFExporter.makePayload(
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
        refreshEmbeddedPDF(session, format: format)
    }
}

private struct PDFKitPreviewView: UIViewRepresentable {
    let url: URL
    @Binding var loadFailed: Bool
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentPage: $currentPage,
            totalPages: $totalPages
        )
    }

    func makeUIView(context: Context) -> FitWidthPDFView {
        let pdfView = FitWidthPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        context.coordinator.attach(to: pdfView)
        loadDocument(into: pdfView, coordinator: context.coordinator)
        return pdfView
    }

    func updateUIView(_ pdfView: FitWidthPDFView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        loadDocument(into: pdfView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ pdfView: FitWidthPDFView, coordinator: Coordinator) {
        coordinator.detach(from: pdfView)
    }

    private func loadDocument(into pdfView: FitWidthPDFView, coordinator: Coordinator) {
        if let data = try? Data(contentsOf: url),
           let document = PDFDocument(data: data),
           document.pageCount > 0 {
            applyDocument(document, to: pdfView, coordinator: coordinator)
            return
        }

        if let document = PDFDocument(url: url), document.pageCount > 0 {
            applyDocument(document, to: pdfView, coordinator: coordinator)
            return
        }

        markLoadFailed()
    }

    private func applyDocument(
        _ document: PDFDocument,
        to pdfView: FitWidthPDFView,
        coordinator: Coordinator
    ) {
        pdfView.document = document
        pdfView.fitToScreenWidth()
        coordinator.updatePageInfo(from: pdfView)
        DispatchQueue.main.async {
            loadFailed = false
        }
    }

    private func markLoadFailed() {
        DispatchQueue.main.async {
            loadFailed = true
            totalPages = 0
        }
    }

    final class Coordinator {
        var loadedURL: URL?
        private var pageObserver: NSObjectProtocol?
        @Binding private var currentPage: Int
        @Binding private var totalPages: Int

        init(currentPage: Binding<Int>, totalPages: Binding<Int>) {
            _currentPage = currentPage
            _totalPages = totalPages
        }

        func attach(to pdfView: PDFView) {
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let pdfView else { return }
                self?.updatePageInfo(from: pdfView)
            }
        }

        func detach(from pdfView: PDFView) {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
                self.pageObserver = nil
            }
        }

        func updatePageInfo(from pdfView: PDFView) {
            guard let document = pdfView.document else {
                totalPages = 0
                return
            }

            totalPages = document.pageCount
            if let page = pdfView.currentPage {
                currentPage = document.index(for: page) + 1
            } else {
                currentPage = min(currentPage, max(totalPages, 1))
            }
        }
    }
}

private final class FitWidthPDFView: PDFView {
    private var lastFitWidth: CGFloat = 0

    override var document: PDFDocument? {
        didSet {
            lastFitWidth = 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitToScreenWidth()
    }

    func fitToScreenWidth() {
        guard bounds.width > 0, document != nil else { return }

        let fitScale = scaleFactorForSizeToFit
        guard fitScale > 0 else { return }

        minScaleFactor = fitScale
        maxScaleFactor = max(fitScale * 4, fitScale)

        let widthChanged = abs(bounds.width - lastFitWidth) > 0.5
        if widthChanged || scaleFactor > fitScale * 1.01 {
            scaleFactor = fitScale
            lastFitWidth = bounds.width
        }

        configureScrollViews(in: self)
    }

    private func configureScrollViews(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.alwaysBounceHorizontal = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.isDirectionalLockEnabled = true
        }
        for subview in view.subviews {
            configureScrollViews(in: subview)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

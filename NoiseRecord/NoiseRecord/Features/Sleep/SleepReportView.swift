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
        HStack(spacing: 8) {
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
                        .frame(height: 160)
                    } else if let embeddedPDFURL {
                        PDFPagesStackView(
                            url: embeddedPDFURL,
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
    @Binding var loadFailed: Bool
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    @State private var pageImages: [UIImage] = []
    @State private var renderWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            if pageImages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                ForEach(Array(pageImages.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
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
        .task(id: "\(url.absoluteString)-\(renderWidth)") {
            await loadPages()
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
            totalPages = 0
            return
        }

        var images: [UIImage] = []
        images.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let image = PDFPageImageRenderer.render(page: page, targetWidth: renderWidth) else {
                continue
            }
            images.append(image)
        }

        guard !images.isEmpty else {
            loadFailed = true
            pageImages = []
            totalPages = 0
            return
        }

        pageImages = images
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

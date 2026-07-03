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
    @State private var pdfPreviewItem: PreviewPDFItem?

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
            .fullScreenCover(item: $pdfPreviewItem) { item in
                ForensicPDFPreviewView(
                    url: item.url,
                    theme: theme,
                    onDismiss: { pdfPreviewItem = nil }
                )
            }
        }
        .tint(theme.accent)
        .observesAppLanguage()
        .paywallPresenter()
        .task(id: sessionID) {
            loadSession()
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
                exportPDF(session)
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

    private func exportPDF(_ session: SleepNoiseSession) {
        guard SubscriptionManager.shared.canAccessSleepExport else {
            PaywallPresenter.shared.present(context: .sleepExport)
            return
        }
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
        guard let url = SleepForensicPDFExporter.export(payload: payload) else { return }
        pdfPreviewItem = PreviewPDFItem(url: url)
    }
}

private struct PreviewPDFItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ForensicPDFPreviewView: View {
    let url: URL
    let theme: ModeVisualTheme
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView(
                        L10n.sleepReportExportPDF,
                        systemImage: "doc.richtext",
                        description: Text(L10n.errorTitle)
                    )
                } else {
                    PDFKitPreviewView(url: url, loadFailed: $loadFailed)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.sleepReportExportPDF)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.close, action: onDismiss)
                        .foregroundStyle(theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label(L10n.share, systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(theme.accent)
                    .disabled(loadFailed)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [url])
            }
        }
        .tint(theme.accent)
    }
}

private struct PDFKitPreviewView: UIViewRepresentable {
    let url: URL
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        loadDocument(into: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        loadDocument(into: pdfView)
    }

    private func loadDocument(into pdfView: PDFView) {
        if let data = try? Data(contentsOf: url),
           let document = PDFDocument(data: data),
           document.pageCount > 0 {
            applyDocument(document, to: pdfView)
            return
        }

        if let document = PDFDocument(url: url), document.pageCount > 0 {
            applyDocument(document, to: pdfView)
            return
        }

        markLoadFailed()
    }

    private func applyDocument(_ document: PDFDocument, to pdfView: PDFView) {
        pdfView.document = document
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        DispatchQueue.main.async {
            loadFailed = false
        }
    }

    private func markLoadFailed() {
        DispatchQueue.main.async {
            loadFailed = true
        }
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import PDFKit
import SwiftUI
import UIKit

enum PDFPreviewBlurGate {
    static func blurSectionMarker(for format: SleepForensicReportFormat) -> String {
        switch format {
        case .legacyOvernight:
            "2. EXECUTIVE SUMMARY"
        case .nighttimeEnvironmental:
            // Always contains English "References & Standards" (primary or secondary).
            "References & Standards"
        }
    }

    static func fallbackBlurStartRatio(for format: SleepForensicReportFormat) -> CGFloat {
        switch format {
        case .legacyOvernight:
            0.42
        case .nighttimeEnvironmental:
            0.28
        }
    }

    /// 返回从页面顶部起算、保留清晰区域所占高度比例（0…1）。
    static func clearTopRatio(on page: PDFPage, sectionMarker: String) -> CGFloat? {
        guard let text = page.string,
              let range = text.range(of: sectionMarker) else {
            return nil
        }
        let nsRange = NSRange(range, in: text)
        guard let selection = page.selection(for: nsRange) else { return nil }

        let bounds = selection.bounds(for: page)
        let pageHeight = page.bounds(for: .mediaBox).height
        guard pageHeight > 0 else { return nil }

        let topFromPageTop = pageHeight - bounds.maxY
        return min(max(topFromPageTop / pageHeight, 0), 1)
    }

    static func clearTopRatio(
        forPageIndex pageIndex: Int,
        page: PDFPage,
        format: SleepForensicReportFormat,
        isPreviewBlurred: Bool
    ) -> CGFloat {
        guard isPreviewBlurred else { return 1 }
        if pageIndex == 0 {
            return clearTopRatio(on: page, sectionMarker: blurSectionMarker(for: format))
                ?? fallbackBlurStartRatio(for: format)
        }
        return 0
    }
}

struct BlurredPDFPageImage: View {
    let image: UIImage
    /// 页面顶部保持清晰的高度比例；1 表示不模糊，0 表示整页模糊。
    let clearTopRatio: CGFloat

    /// 轻度模糊：保留文字轮廓，但无法阅读。
    private let blurRadius: CGFloat = 4
    private let scrimOpacity: CGFloat = 0.08

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()

            if clearTopRatio < 1 {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .blur(radius: blurRadius)
                    .mask(alignment: .top) {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                Spacer(minLength: geometry.size.height * clearTopRatio)
                                Rectangle()
                            }
                        }
                    }

                Color.white.opacity(scrimOpacity)
                    .mask(alignment: .top) {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                Spacer(minLength: geometry.size.height * clearTopRatio)
                                Rectangle()
                            }
                        }
                    }
            }
        }
    }
}

/// 固定在晨报第一屏底部的 VIP 解锁入口。
struct PDFPreviewUnlockBar: View {
    let theme: ModeVisualTheme
    var title: String = L10n.sleepReportPDFUnlockTitle
    var subtitle: String = L10n.paywallContextSleepExport
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(L10n.paywallCTASubscribeNow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PDFPreviewWatermarkOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let cols = Int(geometry.size.width / 180) + 2
            let rows = Int(geometry.size.height / 120) + 2
            ZStack {
                ForEach(0..<(cols * rows), id: \.self) { index in
                    let col = index % cols
                    let row = index / cols
                    Text(L10n.sleepReportPDFWatermark)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.16))
                        .rotationEffect(.degrees(-32))
                        .position(
                            x: CGFloat(col) * 180 - 20,
                            y: CGFloat(row) * 120 + 40
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .allowsHitTesting(false)
        }
    }
}

import PDFKit
import SwiftUI
import UIKit

enum PDFPreviewBlurGate {
    static func blurSectionMarker(for format: SleepForensicReportFormat) -> String {
        switch format {
        case .legacyOvernight:
            "2. EXECUTIVE SUMMARY"
        case .nighttimeEnvironmental:
            "2. 监测依据与参考标准"
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
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.sleepReportPDFUnlockTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(L10n.paywallContextSleepExport)
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

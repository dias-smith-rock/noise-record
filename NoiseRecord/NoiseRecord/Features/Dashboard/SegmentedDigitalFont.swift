import CoreText
import SwiftUI
import UIKit

/// 7 段数码管字体解析：优先使用打包的 DSEG7，缺失时回退系统等宽粗体。
enum SegmentedDigitalFont {
    private static let bundledFileName = "DSEG7Classic-Bold"
    private static let bundledExtension = "ttf"

    private static let candidates = [
        "DSEG7 Classic-Bold",
        "DSEG7Classic-Bold",
        "DSEG7 Modern-Bold",
        "DSEG7Modern-Classic",
        "Digital-7",
    ]

    private static var didRunDiagnostics = false
    private static var didAttemptRuntimeRegistration = false
    private static var cachedResolvedName: String?

    static var usesBundledFont: Bool {
        resolveFontName() != nil
    }

    static func font(size: CGFloat) -> Font {
        if let resolvedName = resolveFontName() {
            return .custom(resolvedName, size: size)
        }
        return .system(size: size, weight: .bold, design: .monospaced)
    }

    /// 进入全屏 LED 看板时调用，输出字体链路诊断埋点。
    static func diagnoseAndLog(context: String = "fullscreen_led") {
        guard !didRunDiagnostics else { return }
        didRunDiagnostics = true

        registerBundledFontIfNeeded()

        let bundleURL = Bundle.main.url(
            forResource: bundledFileName,
            withExtension: bundledExtension
        )
        let bundlePathExists = bundleURL != nil
        let infoPlistFonts = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] ?? []
        let matchingFamilies = UIFont.familyNames.filter {
            $0.localizedCaseInsensitiveContains("DSEG") || $0.localizedCaseInsensitiveContains("Digital")
        }
        let candidateResults = candidates.map { name -> [String: String] in
            [
                "name": name,
                "available": String(UIFont(name: name, size: 12) != nil),
            ]
        }
        let resolvedName = resolveFontName(forceRefresh: true)
        let usesFallback = resolvedName == nil

        var metadata: [String: String] = [
            "context": context,
            "bundle_path_exists": String(bundlePathExists),
            "bundle_path": bundleURL?.lastPathComponent ?? "missing",
            "info_plist_font_count": String(infoPlistFonts.count),
            "info_plist_fonts": infoPlistFonts.joined(separator: ","),
            "matching_family_count": String(matchingFamilies.count),
            "matching_families": matchingFamilies.joined(separator: ","),
            "resolved_name": resolvedName ?? "none",
            "uses_fallback": String(usesFallback),
            "runtime_register_attempted": String(didAttemptRuntimeRegistration),
        ]

        for (index, result) in candidateResults.enumerated() {
            metadata["candidate_\(index)_name"] = result["name"] ?? ""
            metadata["candidate_\(index)_available"] = result["available"] ?? "false"
        }

        if usesFallback {
            metadata["failure_reason"] = diagnoseFailureReason(
                bundlePathExists: bundlePathExists,
                infoPlistFonts: infoPlistFonts,
                matchingFamilies: matchingFamilies
            )
        }

        AppTelemetry.logUIFontDiagnostics(step: usesFallback ? "fallback" : "resolved", metadata: metadata)
    }

    private static func resolveFontName(forceRefresh: Bool = false) -> String? {
        if !forceRefresh, let cachedResolvedName {
            return cachedResolvedName
        }

        registerBundledFontIfNeeded()

        let resolved = candidates.first { UIFont(name: $0, size: 12) != nil }
        cachedResolvedName = resolved
        return resolved
    }

    private static func registerBundledFontIfNeeded() {
        guard !didAttemptRuntimeRegistration else { return }
        didAttemptRuntimeRegistration = true

        guard let url = Bundle.main.url(
            forResource: bundledFileName,
            withExtension: bundledExtension
        ) else {
            AppTelemetry.logUIFontDiagnostics(
                step: "runtime_register_skipped",
                metadata: ["reason": "bundle_url_missing"]
            )
            return
        }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        let errorMessage = error?.takeRetainedValue().localizedDescription ?? ""

        AppTelemetry.logUIFontDiagnostics(
            step: registered ? "runtime_register_succeeded" : "runtime_register_failed",
            metadata: [
                "file": url.lastPathComponent,
                "error": errorMessage,
            ]
        )
    }

    private static func diagnoseFailureReason(
        bundlePathExists: Bool,
        infoPlistFonts: [String],
        matchingFamilies: [String]
    ) -> String {
        if !bundlePathExists {
            return "font_file_missing_in_bundle"
        }
        if infoPlistFonts.isEmpty {
            return "ui_app_fonts_missing_in_info_plist"
        }
        if matchingFamilies.isEmpty {
            return "dseg_family_not_registered"
        }
        return "postscript_name_mismatch"
    }
}

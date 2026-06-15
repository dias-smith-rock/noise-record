#!/usr/bin/env python3
"""Merge launch-readiness localization keys into Localizable.xcstrings."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "NoiseRecord"
CATALOG = ROOT / "Localizable.xcstrings"

LANGS = ["en", "ar", "es", "fr", "hi", "pt", "ru", "zh-Hans", "zh-Hant"]

# English source strings; other locales fall back to English where not listed.
NEW_STRINGS = {
    "REC": {
        "en": "REC",
        "zh-Hans": "录制",
        "zh-Hant": "錄製",
    },
    "aiLabel.%@": {
        "en": "%@",
        "zh-Hans": "%@",
        "zh-Hant": "%@",
    },
    "permission.openSettings": {
        "en": "Open Settings",
        "zh-Hans": "打开设置",
        "zh-Hant": "打開設定",
    },
    "permission.microphone.denied.title": {
        "en": "Microphone Access Required",
        "zh-Hans": "需要麦克风权限",
        "zh-Hant": "需要麥克風權限",
    },
    "permission.microphone.denied.message": {
        "en": "DecibelPro needs microphone access to measure sound levels and record audio. Enable it in Settings.",
        "zh-Hans": "DecibelPro 需要麦克风权限以测量噪声并录音。请在设置中开启。",
        "zh-Hant": "DecibelPro 需要麥克風權限以測量噪聲並錄音。請在設定中開啟。",
    },
    "permission.camera.denied.title": {
        "en": "Camera Access Required",
        "zh-Hans": "需要相机权限",
        "zh-Hant": "需要相機權限",
    },
    "permission.camera.denied.message": {
        "en": "Camera access is required for video evidence. Enable it in Settings.",
        "zh-Hans": "录像取证需要相机权限。请在设置中开启。",
        "zh-Hant": "錄影取證需要相機權限。請在設定中開啟。",
    },
    "permission.location.denied.title": {
        "en": "Location Access",
        "zh-Hans": "定位权限",
        "zh-Hant": "定位權限",
    },
    "permission.location.denied.message": {
        "en": "Location is optional. Video can still be recorded without GPS in the watermark. Enable location in Settings to embed coordinates.",
        "zh-Hans": "定位为可选项。未授权时仍可录像，但水印中不会包含 GPS。如需嵌入坐标，请在设置中开启定位。",
        "zh-Hant": "定位為可選項。未授權時仍可錄影，但浮水印中不會包含 GPS。如需嵌入座標，請在設定中開啟定位。",
    },
    "recorder.monitoringRequired.title": {
        "en": "Monitoring Required",
        "zh-Hans": "需先开始监测",
        "zh-Hant": "需先開始監測",
    },
    "recorder.monitoringRequired.message": {
        "en": "Voice-activated recording runs on the live monitoring pipeline. Start monitoring to enable auto-recording.",
        "zh-Hans": "声控录音依赖实时监测。请先开始监测以启用自动录音。",
        "zh-Hant": "聲控錄音依賴即時監測。請先開始監測以啟用自動錄音。",
    },
    "recorder.monitoringRequired.start": {
        "en": "Start Monitoring",
        "zh-Hans": "开始监测",
        "zh-Hant": "開始監測",
    },
    "recorder.threshold.invalid": {
        "en": "Start threshold must be higher than stop threshold.",
        "zh-Hans": "启动阈值必须高于停止阈值。",
        "zh-Hant": "啟動閾值必須高於停止閾值。",
    },
    "recorder.aiFilter.empty": {
        "en": "Select at least one sound type, or turn off AI filtering.",
        "zh-Hans": "请至少选择一种声音类型，或关闭 AI 筛选。",
        "zh-Hant": "請至少選擇一種聲音類型，或關閉 AI 篩選。",
    },
    "dashboard.exportCSV.failed": {
        "en": "Could not export measurement data. Try again.",
        "zh-Hans": "无法导出测量数据，请重试。",
        "zh-Hant": "無法匯出測量資料，請重試。",
    },
    "files.rename.failed": {
        "en": "Could not rename file. The original name was kept.",
        "zh-Hans": "重命名失败，已保留原文件名。",
        "zh-Hant": "重新命名失敗，已保留原檔名。",
    },
    "files.batchShare": {
        "en": "Share Selected",
        "zh-Hans": "分享所选",
        "zh-Hant": "分享所選",
    },
    "files.fileHash": {
        "en": "SHA-256",
        "zh-Hans": "SHA-256",
        "zh-Hant": "SHA-256",
    },
    "files.exportRecordingsCSV": {
        "en": "Export Recording Log",
        "zh-Hans": "导出录音日志",
        "zh-Hant": "匯出錄音日誌",
    },
    "files.exportRecordingsCSV.failed": {
        "en": "Could not export recording log.",
        "zh-Hans": "无法导出录音日志。",
        "zh-Hant": "無法匯出錄音日誌。",
    },
    "settings.about.header": {
        "en": "About",
        "zh-Hans": "关于",
        "zh-Hant": "關於",
    },
    "settings.version": {
        "en": "Version",
        "zh-Hans": "版本",
        "zh-Hant": "版本",
    },
    "settings.privacyPolicy": {
        "en": "Privacy Policy",
        "zh-Hans": "隐私政策",
        "zh-Hant": "隱私權政策",
    },
    "settings.support": {
        "en": "Support",
        "zh-Hans": "支持",
        "zh-Hant": "支援",
    },
    "settings.disclaimer.title": {
        "en": "Measurement Disclaimer",
        "zh-Hans": "测量免责声明",
        "zh-Hant": "測量免責聲明",
    },
    "settings.disclaimer.body": {
        "en": "DecibelPro uses your iPhone microphone and is not a certified sound level meter. Readings are estimates for personal reference and evidence documentation only.",
        "zh-Hans": "DecibelPro 使用手机麦克风，并非认证声级计。读数仅供个人参考与取证记录，不构成专业测量结果。",
        "zh-Hant": "DecibelPro 使用手機麥克風，並非認證聲級計。讀數僅供個人參考與取證記錄，不構成專業測量結果。",
    },
    "settings.data.header": {
        "en": "Data",
        "zh-Hans": "数据",
        "zh-Hant": "資料",
    },
    "settings.measurementSampleCount": {
        "en": "Measurement samples",
        "zh-Hans": "测量样本数",
        "zh-Hant": "測量樣本數",
    },
    "settings.clearMeasurements": {
        "en": "Clear Measurement History",
        "zh-Hans": "清除测量历史",
        "zh-Hant": "清除測量歷史",
    },
    "settings.clearMeasurements.confirm": {
        "en": "Delete all stored measurement samples? This cannot be undone.",
        "zh-Hans": "删除所有已存储的测量样本？此操作无法撤销。",
        "zh-Hant": "刪除所有已儲存的測量樣本？此操作無法撤銷。",
    },
    "settings.clearMeasurements.done": {
        "en": "Measurement history cleared.",
        "zh-Hans": "测量历史已清除。",
        "zh-Hant": "測量歷史已清除。",
    },
    "error.storage.init.title": {
        "en": "Storage Unavailable",
        "zh-Hans": "存储不可用",
        "zh-Hant": "儲存不可用",
    },
    "error.storage.init.message": {
        "en": "Could not open app storage: %@",
        "zh-Hans": "无法打开应用存储：%@",
        "zh-Hant": "無法開啟應用儲存：%@",
    },
    "error.storage.init.retry": {
        "en": "Try Again",
        "zh-Hans": "重试",
        "zh-Hant": "重試",
    },
    "error.aiClassification.failed": {
        "en": "Sound classification is temporarily unavailable.",
        "zh-Hans": "声音分类暂时不可用。",
        "zh-Hant": "聲音分類暫時不可用。",
    },
    "video.previewRecording": {
        "en": "Preview Recording",
        "zh-Hans": "预览录像",
        "zh-Hant": "預覽錄影",
    },
    "overlay.gps.coordinates": {
        "en": "Lat: %1$.4f, Lon: %2$.4f",
        "zh-Hans": "纬度: %1$.4f, 经度: %2$.4f",
        "zh-Hant": "緯度: %1$.4f, 經度: %2$.4f",
    },
    "settings.rateApp": {
        "en": "Rate DecibelPro",
        "zh-Hans": "为 DecibelPro 评分",
        "zh-Hant": "為 DecibelPro 評分",
    },
    "settings.reviewApp": {
        "en": "Review DecibelPro",
        "zh-Hans": "为 DecibelPro 写评论",
        "zh-Hant": "為 DecibelPro 寫評論",
    },
    "settings.review.prompt.title": {
        "en": "Share Your Experience",
        "zh-Hans": "分享你的使用体验",
        "zh-Hant": "分享你的使用體驗",
    },
    "settings.review.prompt.message": {
        "en": "Your review helps others find a reliable noise evidence tool. Tell us what works for you on the App Store — a few words about your experience means a lot.",
        "zh-Hans": "你的评论能帮助更多人找到可靠的噪声取证工具。欢迎在 App Store 写下使用感受，哪怕几句话也很有价值。",
        "zh-Hant": "你的評論能幫助更多人找到可靠的噪聲取證工具。歡迎在 App Store 寫下使用感受，哪怕幾句話也很有價值。",
    },
    "settings.review.action": {
        "en": "Write a Review",
        "zh-Hans": "前往写评论",
        "zh-Hant": "前往寫評論",
    },
    "appReview.prompt.title": {
        "en": "Enjoying DecibelPro?",
        "zh-Hans": "喜欢 DecibelPro 吗？",
        "zh-Hant": "喜歡 DecibelPro 嗎？",
    },
    "appReview.prompt.message": {
        "en": "If this app helps you document noise, a quick App Store review would mean a lot.",
        "zh-Hans": "如果这款应用对你记录噪声有帮助，欢迎在 App Store 给我们评分。",
        "zh-Hant": "如果這款 App 對你記錄噪聲有幫助，歡迎在 App Store 為我們評分。",
    },
    "appReview.rateNow": {
        "en": "Rate on App Store",
        "zh-Hans": "前往 App Store 评分",
        "zh-Hant": "前往 App Store 評分",
    },
    "appReview.later": {
        "en": "Maybe Later",
        "zh-Hans": "以后再说",
        "zh-Hant": "以後再說",
    },
    "liveActivity.scene.whisper": {
        "en": "Whisper quiet",
        "zh-Hans": "悄悄话",
        "zh-Hant": "悄悄話",
    },
    "liveActivity.scene.conversation": {
        "en": "Normal conversation",
        "zh-Hans": "正常交谈",
        "zh-Hant": "正常交談",
    },
    "liveActivity.scene.traffic": {
        "en": "Busy traffic",
        "zh-Hans": "繁忙交通",
        "zh-Hant": "繁忙交通",
    },
    "liveActivity.scene.drill": {
        "en": "Power drill",
        "zh-Hans": "电钻施工",
        "zh-Hant": "電鑽施工",
    },
    "liveActivity.status.monitoringStandard": {
        "en": "Monitoring in standard mode…",
        "zh-Hans": "正在标准模式监测中…",
        "zh-Hant": "正在標準模式監測中…",
    },
    "liveActivity.status.monitoringHighSensitivity": {
        "en": "High-sensitivity monitoring…",
        "zh-Hans": "正在高灵敏侦测中…",
        "zh-Hant": "正在高靈敏偵測中…",
    },
    "liveActivity.status.voiceRecording": {
        "en": "Voice-triggered recording active",
        "zh-Hans": "声控录音已唤醒",
        "zh-Hant": "聲控錄音已喚醒",
    },
    "liveActivity.status.voiceStandby": {
        "en": "Voice standby, still monitoring…",
        "zh-Hans": "声控待命，持续监测中…",
        "zh-Hant": "聲控待命，持續監測中…",
    },
    "liveActivity.status.ended": {
        "en": "Monitoring stopped",
        "zh-Hans": "监测已停止",
        "zh-Hant": "監測已停止",
    },
}


def make_entry(translations: dict) -> dict:
    localizations = {}
    for lang in LANGS:
        value = translations.get(lang, translations["en"])
        localizations[lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value,
            }
        }
    return {
        "extractionState": "manual",
        "localizations": localizations,
    }


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.setdefault("strings", {})
    for key, translations in NEW_STRINGS.items():
        strings[key] = make_entry(translations)
    # Remove empty placeholder key
    strings.pop("", None)
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {len(NEW_STRINGS)} keys in {CATALOG}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate Localizable.xcstrings and InfoPlist.xcstrings for NoiseRecord."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SOURCE_LANGUAGE = "en"
LOCALES = [
    "en",
    "zh-Hans",
    "zh-Hant",
    "es",
    "pt",
    "ar",
    "fr",
    "hi",
    "ru",
]

REPO_ROOT = Path(__file__).resolve().parent.parent
L10N_SWIFT = REPO_ROOT / "NoiseRecord" / "L10n.swift"
OUT_LOCALIZABLE = REPO_ROOT / "NoiseRecord" / "Localizable.xcstrings"
OUT_INFOPLIST = REPO_ROOT / "NoiseRecord" / "InfoPlist.xcstrings"

EXTRA_LOCALIZABLE_KEYS = [
    "aiLabel.speech",
    "aiLabel.music",
    "aiLabel.dog",
    "aiLabel.cat",
    "aiLabel.car",
    "aiLabel.engine",
    "aiLabel.drill",
    "aiLabel.hammer",
    "aiLabel.alarm",
    "aiLabel.siren",
    "aiLabel.applause",
    "aiLabel.laughter",
    "silenceReport.generated",
    "silenceReport.device",
    "silenceReport.weighting",
    "silenceReport.grade",
    "silenceReport.gradeLine",
    "silenceReport.leq",
    "silenceReport.max",
    "silenceReport.min",
    "silenceReport.avg",
    "silenceReport.disclaimer",
    "settings.calibration.alert.saved.small",
    "settings.calibration.alert.saved.changed",
    "settings.calibration.reset.alert.alreadyDefault.message",
    "settings.calibration.reset.alert.restored.message",
    "files.audio.detailLine",
    "overlay.gps.coordinates",
    "overlay.decibel.default",
]

INFOPLIST_KEYS = [
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSLocationWhenInUseUsageDescription",
    "NSUserTrackingUsageDescription",
]

LOCALIZED_KEY_RE = re.compile(r'String\(localized:\s*"([^"]+)"\)')


def parse_l10n_keys(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    keys = sorted(set(LOCALIZED_KEY_RE.findall(text)))
    return keys


def load_catalog() -> dict[str, dict[str, str]]:
    data = json.loads(CATALOG_JSON)
    if not isinstance(data, dict):
        raise ValueError("Catalog must be a JSON object")
    return data


CATALOG_JSON = """{
  "common.ok": {
    "en": "OK",
    "zh-Hans": "好",
    "zh-Hant": "好",
    "es": "Aceptar",
    "pt": "OK",
    "ar": "حسنًا",
    "fr": "OK",
    "hi": "ठीक",
    "ru": "OK"
  },
  "common.cancel": {
    "en": "Cancel",
    "zh-Hans": "取消",
    "zh-Hant": "取消",
    "es": "Cancelar",
    "pt": "Cancelar",
    "ar": "إلغاء",
    "fr": "Annuler",
    "hi": "रद्द करें",
    "ru": "Отмена"
  },
  "common.close": {
    "en": "Close",
    "zh-Hans": "关闭",
    "zh-Hant": "關閉",
    "es": "Cerrar",
    "pt": "Fechar",
    "ar": "إغلاق",
    "fr": "Fermer",
    "hi": "बंद करें",
    "ru": "Закрыть"
  },
  "common.done": {
    "en": "Done",
    "zh-Hans": "完成",
    "zh-Hant": "完成",
    "es": "Listo",
    "pt": "Concluído",
    "ar": "تم",
    "fr": "Terminé",
    "hi": "हो गया",
    "ru": "Готово"
  },
  "common.save": {
    "en": "Save",
    "zh-Hans": "保存",
    "zh-Hant": "儲存",
    "es": "Guardar",
    "pt": "Salvar",
    "ar": "حفظ",
    "fr": "Enregistrer",
    "hi": "सहेजें",
    "ru": "Сохранить"
  },
  "common.delete": {
    "en": "Delete",
    "zh-Hans": "删除",
    "zh-Hant": "刪除",
    "es": "Eliminar",
    "pt": "Excluir",
    "ar": "حذف",
    "fr": "Supprimer",
    "hi": "हटाएँ",
    "ru": "Удалить"
  },
  "common.share": {
    "en": "Share",
    "zh-Hans": "分享",
    "zh-Hant": "分享",
    "es": "Compartir",
    "pt": "Compartilhar",
    "ar": "مشاركة",
    "fr": "Partager",
    "hi": "साझा करें",
    "ru": "Поделиться"
  },
  "common.rename": {
    "en": "Rename",
    "zh-Hans": "重命名",
    "zh-Hant": "重新命名",
    "es": "Renombrar",
    "pt": "Renomear",
    "ar": "إعادة تسمية",
    "fr": "Renommer",
    "hi": "नाम बदलें",
    "ru": "Переименовать"
  },
  "common.gotIt": {
    "en": "Got it",
    "zh-Hans": "知道了",
    "zh-Hant": "知道了",
    "es": "Entendido",
    "pt": "Entendi",
    "ar": "حسنًا",
    "fr": "Compris",
    "hi": "समझ गया",
    "ru": "Понятно"
  },
  "alert.error.title": {
    "en": "Error",
    "zh-Hans": "错误",
    "zh-Hant": "錯誤",
    "es": "Error",
    "pt": "Erro",
    "ar": "خطأ",
    "fr": "Erreur",
    "hi": "त्रुटि",
    "ru": "Ошибка"
  },
  "tab.monitor": {
    "en": "Monitor",
    "zh-Hans": "监测",
    "zh-Hant": "監測",
    "es": "Monitor",
    "pt": "Monitor",
    "ar": "مراقبة",
    "fr": "Surveillance",
    "hi": "मॉनिटर",
    "ru": "Монитор"
  },
  "tab.voice": {
    "en": "Voice",
    "zh-Hans": "语音",
    "zh-Hant": "語音",
    "es": "Voz",
    "pt": "Voz",
    "ar": "صوت",
    "fr": "Voix",
    "hi": "आवाज़",
    "ru": "Голос"
  },
  "tab.video": {
    "en": "Video",
    "zh-Hans": "视频",
    "zh-Hant": "影片",
    "es": "Vídeo",
    "pt": "Vídeo",
    "ar": "فيديو",
    "fr": "Vidéo",
    "hi": "वीडियो",
    "ru": "Видео"
  },
  "tab.files": {
    "en": "Files",
    "zh-Hans": "文件",
    "zh-Hant": "檔案",
    "es": "Archivos",
    "pt": "Arquivos",
    "ar": "ملفات",
    "fr": "Fichiers",
    "hi": "फ़ाइलें",
    "ru": "Файлы"
  },
  "tab.settings": {
    "en": "Settings",
    "zh-Hans": "设置",
    "zh-Hant": "設定",
    "es": "Ajustes",
    "pt": "Ajustes",
    "ar": "الإعدادات",
    "fr": "Réglages",
    "hi": "सेटिंग्स",
    "ru": "Настройки"
  },
  "dashboard.title": {
    "en": "Noise Monitor",
    "zh-Hans": "噪声监测",
    "zh-Hant": "噪音監測",
    "es": "Monitor de ruido",
    "pt": "Monitor de ruído",
    "ar": "مراقب الضوضاء",
    "fr": "Moniteur de bruit",
    "hi": "शोर मॉनिटर",
    "ru": "Монитор шума"
  },
  "dashboard.stat.max": {
    "en": "Max",
    "zh-Hans": "最大",
    "zh-Hant": "最大",
    "es": "Máx.",
    "pt": "Máx.",
    "ar": "الحد الأقصى",
    "fr": "Max.",
    "hi": "अधिकतम",
    "ru": "Макс."
  },
  "dashboard.stat.min": {
    "en": "Min",
    "zh-Hans": "最小",
    "zh-Hant": "最小",
    "es": "Mín.",
    "pt": "Mín.",
    "ar": "الحد الأدنى",
    "fr": "Min.",
    "hi": "न्यूनतम",
    "ru": "Мин."
  },
  "dashboard.stat.avg": {
    "en": "Avg",
    "zh-Hans": "平均",
    "zh-Hant": "平均",
    "es": "Prom.",
    "pt": "Méd.",
    "ar": "المتوسط",
    "fr": "Moy.",
    "hi": "औसत",
    "ru": "Сред."
  },
  "dashboard.stat.leq": {
    "en": "Leq",
    "zh-Hans": "Leq",
    "zh-Hant": "Leq",
    "es": "Leq",
    "pt": "Leq",
    "ar": "Leq",
    "fr": "Leq",
    "hi": "Leq",
    "ru": "Leq"
  },
  "dashboard.waveform.title": {
    "en": "Waveform",
    "zh-Hans": "波形",
    "zh-Hant": "波形",
    "es": "Forma de onda",
    "pt": "Forma de onda",
    "ar": "موجة الصوت",
    "fr": "Forme d'onde",
    "hi": "तरंगरूप",
    "ru": "Осциллограмма"
  },
  "dashboard.waveform.fullBandBadge": {
    "en": "Full band",
    "zh-Hans": "全频段",
    "zh-Hant": "全頻段",
    "es": "Banda completa",
    "pt": "Banda completa",
    "ar": "نطاق كامل",
    "fr": "Bande complète",
    "hi": "पूर्ण बैंड",
    "ru": "Полная полоса"
  },
  "dashboard.spectrum.title": {
    "en": "Spectrum",
    "zh-Hans": "频谱",
    "zh-Hant": "頻譜",
    "es": "Espectro",
    "pt": "Espectro",
    "ar": "الطيف",
    "fr": "Spectre",
    "hi": "स्पेक्ट्रम",
    "ru": "Спектр"
  },
  "dashboard.button.report": {
    "en": "Report",
    "zh-Hans": "报告",
    "zh-Hant": "報告",
    "es": "Informe",
    "pt": "Relatório",
    "ar": "تقرير",
    "fr": "Rapport",
    "hi": "रिपोर्ट",
    "ru": "Отчёт"
  },
  "dashboard.button.exportCSV": {
    "en": "Export CSV",
    "zh-Hans": "导出 CSV",
    "zh-Hant": "匯出 CSV",
    "es": "Exportar CSV",
    "pt": "Exportar CSV",
    "ar": "تصدير CSV",
    "fr": "Exporter CSV",
    "hi": "CSV निर्यात",
    "ru": "Экспорт CSV"
  },
  "dashboard.button.stop": {
    "en": "Stop",
    "zh-Hans": "停止",
    "zh-Hant": "停止",
    "es": "Detener",
    "pt": "Parar",
    "ar": "إيقاف",
    "fr": "Arrêter",
    "hi": "रोकें",
    "ru": "Стоп"
  },
  "dashboard.button.start": {
    "en": "Start",
    "zh-Hans": "开始",
    "zh-Hant": "開始",
    "es": "Iniciar",
    "pt": "Iniciar",
    "ar": "بدء",
    "fr": "Démarrer",
    "hi": "शुरू",
    "ru": "Старт"
  },
  "dashboard.footer.highSensitivity": {
    "en": "High-sensitivity mode: readings reflect full-band physical sound pressure.",
    "zh-Hans": "高灵敏度模式：读数反映全频段物理声压。",
    "zh-Hant": "高靈敏度模式：讀數反映全頻段物理聲壓。",
    "es": "Modo de alta sensibilidad: las lecturas reflejan la presión sonora física de banda completa.",
    "pt": "Modo de alta sensibilidade: as leituras refletem a pressão sonora física em banda completa.",
    "ar": "وضع الحساسية العالية: تعكس القراءات ضغط الصوت الفيزيائي لكامل النطاق.",
    "fr": "Mode haute sensibilité : les mesures reflètent la pression acoustique physique pleine bande.",
    "hi": "उच्च-संवेदनशीलता मोड: रीडिंग पूर्ण-बैंड भौतिक ध्वनि दबाव दर्शाती हैं।",
    "ru": "Режим высокой чувствительности: показания отражают физическое звуковое давление во всей полосе."
  },
  "dashboard.footer.standard": {
    "en": "Standard mode: readings approximate human hearing (A-weighted).",
    "zh-Hans": "标准模式：读数近似人耳听感（A 计权）。",
    "zh-Hant": "標準模式：讀數近似人耳聽感（A 計權）。",
    "es": "Modo estándar: las lecturas se aproximan a la audición humana (ponderación A).",
    "pt": "Modo padrão: as leituras aproximam a audição humana (ponderação A).",
    "ar": "الوضع القياسي: القراءات تقارب السمع البشري (الترجيح A).",
    "fr": "Mode standard : les mesures approchent l’audition humaine (pondération A).",
    "hi": "मानक मोड: रीडिंग मानव श्रवण (A-भारित) के करीब होती हैं।",
    "ru": "Стандартный режим: показания приближены к восприятию человеком (A-взвешивание)."
  },
  "dashboard.stopPrompt.title": {
    "en": "Stop monitoring?",
    "zh-Hans": "停止监测？",
    "zh-Hant": "停止監測？",
    "es": "¿Detener la monitorización?",
    "pt": "Parar monitoramento?",
    "ar": "إيقاف المراقبة؟",
    "fr": "Arrêter la surveillance ?",
    "hi": "मॉनिटरिंग रोकें?",
    "ru": "Остановить мониторинг?"
  },
  "dashboard.stopPrompt.keep": {
    "en": "Keep recording",
    "zh-Hans": "保留录音",
    "zh-Hant": "保留錄音",
    "es": "Conservar grabación",
    "pt": "Manter gravação",
    "ar": "الاحتفاظ بالتسجيل",
    "fr": "Conserver l’enregistrement",
    "hi": "रिकॉर्डिंग रखें",
    "ru": "Сохранить запись"
  },
  "dashboard.stopPrompt.discard": {
    "en": "Discard",
    "zh-Hans": "丢弃",
    "zh-Hant": "捨棄",
    "es": "Descartar",
    "pt": "Descartar",
    "ar": "تجاهل",
    "fr": "Supprimer",
    "hi": "हटाएँ",
    "ru": "Отменить"
  },
  "dashboard.stopPrompt.keepMonitoring": {
    "en": "Keep monitoring",
    "zh-Hans": "继续监测",
    "zh-Hant": "繼續監測",
    "es": "Seguir monitorizando",
    "pt": "Continuar monitorando",
    "ar": "متابعة المراقبة",
    "fr": "Continuer la surveillance",
    "hi": "मॉनिटरिंग जारी रखें",
    "ru": "Продолжить мониторинг"
  },
  "dashboard.detectedNoise": {
    "en": "Detected: %1$@ (%2$d%%)",
    "zh-Hans": "检测到：%1$@（%2$d%%）",
    "zh-Hant": "偵測到：%1$@（%2$d%%）",
    "es": "Detectado: %1$@ (%2$d%%)",
    "pt": "Detectado: %1$@ (%2$d%%)",
    "ar": "تم اكتشاف: %1$@ (%2$d%%)",
    "fr": "Détecté : %1$@ (%2$d %%)",
    "hi": "पता चला: %1$@ (%2$d%%)",
    "ru": "Обнаружено: %1$@ (%2$d%%)"
  },
  "dashboard.stopPrompt.message.multiple": {
    "en": "%d clips will be saved.",
    "zh-Hans": "将保存 %d 段录音。",
    "zh-Hant": "將儲存 %d 段錄音。",
    "es": "Se guardarán %d clips.",
    "pt": "Serão salvos %d clipes.",
    "ar": "سيتم حفظ %d مقطعًا.",
    "fr": "%d clips seront enregistrés.",
    "hi": "%d क्लिप सहेजी जाएँगी।",
    "ru": "Будет сохранено клипов: %d."
  },
  "dashboard.stopPrompt.message.inProgress": {
    "en": "A recording is in progress.",
    "zh-Hans": "正在录音。",
    "zh-Hant": "正在錄音。",
    "es": "Hay una grabación en curso.",
    "pt": "Há uma gravação em andamento.",
    "ar": "هناك تسجيل قيد التنفيذ.",
    "fr": "Un enregistrement est en cours.",
    "hi": "रिकॉर्डिंग चल रही है।",
    "ru": "Идёт запись."
  },
  "silenceReport.title": {
    "en": "Silence Report",
    "zh-Hans": "静音报告",
    "zh-Hant": "靜音報告",
    "es": "Informe de silencio",
    "pt": "Relatório de silêncio",
    "ar": "تقرير الصمت",
    "fr": "Rapport de silence",
    "hi": "मौन रिपोर्ट",
    "ru": "Отчёт о тишине"
  },
  "silenceReport.header": {
    "en": "Environmental Noise Report",
    "zh-Hans": "环境噪声报告",
    "zh-Hant": "環境噪音報告",
    "es": "Informe de ruido ambiental",
    "pt": "Relatório de ruído ambiental",
    "ar": "تقرير الضوضاء البيئية",
    "fr": "Rapport de bruit ambiant",
    "hi": "पर्यावरणीय शोर रिपोर्ट",
    "ru": "Отчёт об окружающем шуме"
  },
  "recordingStatus.voiceStandby": {
    "en": "Voice standby",
    "zh-Hans": "语音待命",
    "zh-Hant": "語音待命",
    "es": "Voz en espera",
    "pt": "Voz em espera",
    "ar": "انتظار الصوت",
    "fr": "Veille vocale",
    "hi": "वॉइस स्टैंडबाय",
    "ru": "Ожидание голоса"
  },
  "recordingStatus.recording": {
    "en": "Recording",
    "zh-Hans": "录音中",
    "zh-Hant": "錄音中",
    "es": "Grabando",
    "pt": "Gravando",
    "ar": "جارٍ التسجيل",
    "fr": "Enregistrement",
    "hi": "रिकॉर्डिंग",
    "ru": "Запись"
  },
  "recordingStatus.autoRecording": {
    "en": "Auto recording",
    "zh-Hans": "自动录音",
    "zh-Hant": "自動錄音",
    "es": "Grabación automática",
    "pt": "Gravação automática",
    "ar": "تسجيل تلقائي",
    "fr": "Enregistrement auto",
    "hi": "ऑटो रिकॉर्डिंग",
    "ru": "Автозапись"
  },
  "recordingStatus.tailDelay": {
    "en": "Tail delay",
    "zh-Hans": "尾音延时",
    "zh-Hant": "尾音延遲",
    "es": "Retardo final",
    "pt": "Atraso final",
    "ar": "تأخير الذيل",
    "fr": "Délai de fin",
    "hi": "टेल विलंब",
    "ru": "Задержка хвоста"
  },
  "recorderSettings.title": {
    "en": "Recorder",
    "zh-Hans": "录音机",
    "zh-Hant": "錄音機",
    "es": "Grabadora",
    "pt": "Gravador",
    "ar": "مسجل",
    "fr": "Enregistreur",
    "hi": "रिकॉर्डर",
    "ru": "Диктофон"
  },
  "recorderSettings.voiceActivated.title": {
    "en": "Voice-activated recording",
    "zh-Hans": "声控录音",
    "zh-Hant": "聲控錄音",
    "es": "Grabación por voz",
    "pt": "Gravação por voz",
    "ar": "تسجيل بالصوت",
    "fr": "Enregistrement vocal",
    "hi": "वॉइस-सक्रिय रिकॉर्डिंग",
    "ru": "Голосовая активация"
  },
  "recorderSettings.voiceActivated.subtitle": {
    "en": "Start and stop clips when sound crosses your thresholds.",
    "zh-Hans": "声音超过阈值时自动开始和停止录音。",
    "zh-Hant": "聲音超過閾值時自動開始和停止錄音。",
    "es": "Inicia y detiene clips cuando el sonido supera tus umbrales.",
    "pt": "Inicia e para clipes quando o som ultrapassa seus limites.",
    "ar": "يبدأ ويوقف المقاطع عند تجاوز الصوت للحدود.",
    "fr": "Démarre et arrête les clips lorsque le son dépasse vos seuils.",
    "hi": "ध्वनि सीमा पार करने पर क्लिप शुरू/रोकें।",
    "ru": "Запускает и останавливает клипы при пересечении порогов."
  },
  "recorderSettings.backgroundMonitoring.title": {
    "en": "Background monitoring",
    "zh-Hans": "后台监测",
    "zh-Hant": "背景監測",
    "es": "Monitorización en segundo plano",
    "pt": "Monitoramento em segundo plano",
    "ar": "مراقبة في الخلفية",
    "fr": "Surveillance en arrière-plan",
    "hi": "पृष्ठभूमि मॉनिटरिंग",
    "ru": "Фоновый мониторинг"
  },
  "recorderSettings.backgroundMonitoring.subtitle": {
    "en": "Keep measuring noise while using other tabs.",
    "zh-Hans": "使用其他标签页时继续测量噪声。",
    "zh-Hant": "使用其他標籤時繼續測量噪音。",
    "es": "Sigue midiendo el ruido mientras usas otras pestañas.",
    "pt": "Continue medindo o ruído em outras abas.",
    "ar": "استمر في قياس الضوضاء أثناء استخدام علامات أخرى.",
    "fr": "Continue de mesurer le bruit dans les autres onglets.",
    "hi": "अन्य टैब पर भी शोर मापते रहें।",
    "ru": "Продолжайте измерять шум в других вкладках."
  },
  "recorderSettings.metric.start": {
    "en": "Start",
    "zh-Hans": "启动",
    "zh-Hant": "啟動",
    "es": "Inicio",
    "pt": "Início",
    "ar": "بدء",
    "fr": "Début",
    "hi": "शुरू",
    "ru": "Старт"
  },
  "recorderSettings.metric.stop": {
    "en": "Stop",
    "zh-Hans": "停止",
    "zh-Hant": "停止",
    "es": "Parada",
    "pt": "Parada",
    "ar": "إيقاف",
    "fr": "Fin",
    "hi": "रोक",
    "ru": "Стоп"
  },
  "recorderSettings.metric.currentDb": {
    "en": "Current dB",
    "zh-Hans": "当前 dB",
    "zh-Hant": "目前 dB",
    "es": "dB actual",
    "pt": "dB atual",
    "ar": "dB الحالي",
    "fr": "dB actuel",
    "hi": "वर्तमान dB",
    "ru": "Текущий dB"
  },
  "recorderSettings.status.off": {
    "en": "Off",
    "zh-Hans": "关",
    "zh-Hant": "關",
    "es": "Apagado",
    "pt": "Desligado",
    "ar": "إيقاف",
    "fr": "Désactivé",
    "hi": "बंद",
    "ru": "Выкл."
  },
  "recorderSettings.thresholds.title": {
    "en": "Thresholds",
    "zh-Hans": "阈值",
    "zh-Hant": "閾值",
    "es": "Umbrales",
    "pt": "Limites",
    "ar": "الحدود",
    "fr": "Seuils",
    "hi": "सीमाएँ",
    "ru": "Пороги"
  },
  "recorderSettings.thresholds.subtitle": {
    "en": "Set when recording starts and stops.",
    "zh-Hans": "设置录音开始和停止的条件。",
    "zh-Hant": "設定錄音開始和停止的條件。",
    "es": "Define cuándo empieza y termina la grabación.",
    "pt": "Defina quando a gravação começa e para.",
    "ar": "حدد متى يبدأ التسجيل ويتوقف.",
    "fr": "Définissez le début et la fin de l’enregistrement.",
    "hi": "रिकॉर्डिंग शुरू/रुकने की सीमा सेट करें।",
    "ru": "Задайте условия начала и остановки записи."
  },
  "recorderSettings.thresholds.start": {
    "en": "Start threshold",
    "zh-Hans": "启动阈值",
    "zh-Hant": "啟動閾值",
    "es": "Umbral de inicio",
    "pt": "Limite de início",
    "ar": "حد البدء",
    "fr": "Seuil de démarrage",
    "hi": "शुरू सीमा",
    "ru": "Порог старта"
  },
  "recorderSettings.thresholds.stop": {
    "en": "Stop threshold",
    "zh-Hans": "停止阈值",
    "zh-Hant": "停止閾值",
    "es": "Umbral de parada",
    "pt": "Limite de parada",
    "ar": "حد الإيقاف",
    "fr": "Seuil d’arrêt",
    "hi": "रोक सीमा",
    "ru": "Порог остановки"
  },
  "recorderSettings.thresholds.modeHint": {
    "en": "Thresholds apply in %1$@ mode.",
    "zh-Hans": "阈值适用于 %1$@ 模式。",
    "zh-Hant": "閾值適用於 %1$@ 模式。",
    "es": "Los umbrales se aplican en modo %1$@.",
    "pt": "Os limites aplicam-se no modo %1$@.",
    "ar": "تُطبَّق الحدود في وضع %1$@.",
    "fr": "Les seuils s’appliquent en mode %1$@.",
    "hi": "सीमाएँ %1$@ मोड में लागू होती हैं।",
    "ru": "Пороги действуют в режиме %1$@."
  },
  "recorderSettings.ai.title": {
    "en": "AI sound labels",
    "zh-Hans": "AI 声音标签",
    "zh-Hant": "AI 聲音標籤",
    "es": "Etiquetas de sonido con IA",
    "pt": "Rótulos de som com IA",
    "ar": "تصنيفات الصوت بالذكاء الاصطناعي",
    "fr": "Étiquettes sonores IA",
    "hi": "AI ध्वनि लेबल",
    "ru": "Метки звука ИИ"
  },
  "recorderSettings.ai.subtitle": {
    "en": "Show detected sound types on the dashboard.",
    "zh-Hans": "在仪表盘显示检测到的声音类型。",
    "zh-Hant": "在儀表板顯示偵測到的聲音類型。",
    "es": "Muestra tipos de sonido detectados en el panel.",
    "pt": "Mostra tipos de som detectados no painel.",
    "ar": "اعرض أنواع الصوت المكتشفة في لوحة المعلومات.",
    "fr": "Affiche les types de sons détectés sur le tableau de bord.",
    "hi": "डैशबोर्ड पर पहचाने गए ध्वनि प्रकार दिखाएँ।",
    "ru": "Показывать типы звуков на панели."
  },
  "recorderSettings.aiFilter.title": {
    "en": "AI recording filter",
    "zh-Hans": "AI 录音过滤",
    "zh-Hant": "AI 錄音過濾",
    "es": "Filtro de grabación con IA",
    "pt": "Filtro de gravação com IA",
    "ar": "مرشح التسجيل بالذكاء الاصطناعي",
    "fr": "Filtre d’enregistrement IA",
    "hi": "AI रिकॉर्डिंग फ़िल्टर",
    "ru": "Фильтр записи ИИ"
  },
  "recorderSettings.aiFilter.subtitle": {
    "en": "Only keep clips that match selected sound types.",
    "zh-Hans": "仅保留匹配所选声音类型的片段。",
    "zh-Hant": "僅保留符合所選聲音類型的片段。",
    "es": "Conserva solo clips que coincidan con los tipos seleccionados.",
    "pt": "Mantenha apenas clipes dos tipos selecionados.",
    "ar": "احتفظ فقط بالمقاطع المطابقة للأنواع المحددة.",
    "fr": "Ne conserve que les clips correspondant aux types choisis.",
    "hi": "केवल चुने ध्वनि प्रकार के क्लिप रखें।",
    "ru": "Сохранять только клипы выбранных типов звука."
  },
  "recorderSettings.footer": {
    "en": "Voice-activated clips are saved as audio files in the Files tab.",
    "zh-Hans": "声控录音片段会保存为音频文件，可在“文件”标签查看。",
    "zh-Hant": "聲控錄音片段會儲存為音訊檔案，可在「檔案」標籤查看。",
    "es": "Los clips por voz se guardan como audio en la pestaña Archivos.",
    "pt": "Clipes por voz são salvos como áudio na aba Arquivos.",
    "ar": "تُحفظ مقاطع الصوت كملفات صوتية في تبويب الملفات.",
    "fr": "Les clips vocaux sont enregistrés en audio dans l’onglet Fichiers.",
    "hi": "वॉइस क्लिप ऑडियो के रूप में फ़ाइलें टैब में सहेजे जाते हैं।",
    "ru": "Голосовые клипы сохраняются как аудио во вкладке «Файлы»."
  },
  "video.title": {
    "en": "Video evidence",
    "zh-Hans": "视频取证",
    "zh-Hant": "影片取證",
    "es": "Prueba en vídeo",
    "pt": "Prova em vídeo",
    "ar": "دليل فيديو",
    "fr": "Preuve vidéo",
    "hi": "वीडियो साक्ष्य",
    "ru": "Видеодоказательство"
  },
  "video.metric.currentDb": {
    "en": "Current dB",
    "zh-Hans": "当前 dB",
    "zh-Hant": "目前 dB",
    "es": "dB actual",
    "pt": "dB atual",
    "ar": "dB الحالي",
    "fr": "dB actuel",
    "hi": "वर्तमान dB",
    "ru": "Текущий dB"
  },
  "video.metric.clipPeak": {
    "en": "Clip peak",
    "zh-Hans": "片段峰值",
    "zh-Hant": "片段峰值",
    "es": "Pico del clip",
    "pt": "Pico do clipe",
    "ar": "ذروة المقطع",
    "fr": "Pic du clip",
    "hi": "क्लिप पीक",
    "ru": "Пик клипа"
  },
  "video.metric.gps": {
    "en": "GPS",
    "zh-Hans": "GPS",
    "zh-Hant": "GPS",
    "es": "GPS",
    "pt": "GPS",
    "ar": "GPS",
    "fr": "GPS",
    "hi": "GPS",
    "ru": "GPS"
  },
  "video.gps.located": {
    "en": "Located",
    "zh-Hans": "已定位",
    "zh-Hant": "已定位",
    "es": "Ubicado",
    "pt": "Localizado",
    "ar": "تم تحديد الموقع",
    "fr": "Localisé",
    "hi": "स्थान मिला",
    "ru": "Определено"
  },
  "video.gps.pending": {
    "en": "Pending",
    "zh-Hans": "等待中",
    "zh-Hant": "等待中",
    "es": "Pendiente",
    "pt": "Pendente",
    "ar": "قيد الانتظار",
    "fr": "En attente",
    "hi": "लंबित",
    "ru": "Ожидание"
  },
  "video.hint.autoMonitoring": {
    "en": "Noise monitoring runs automatically while recording.",
    "zh-Hans": "录制时自动进行噪声监测。",
    "zh-Hant": "錄製時自動進行噪音監測。",
    "es": "La monitorización de ruido se ejecuta automáticamente al grabar.",
    "pt": "O monitoramento de ruído roda automaticamente durante a gravação.",
    "ar": "تعمل مراقبة الضوضاء تلقائيًا أثناء التسجيل.",
    "fr": "La surveillance du bruit démarre automatiquement pendant l’enregistrement.",
    "hi": "रिकॉर्डिंग के दौरान शोर मॉनिटरिंग स्वचालित चलती है।",
    "ru": "Мониторинг шума включается автоматически при записи."
  },
  "video.button.stopAndSave": {
    "en": "Stop & save",
    "zh-Hans": "停止并保存",
    "zh-Hant": "停止並儲存",
    "es": "Detener y guardar",
    "pt": "Parar e salvar",
    "ar": "إيقاف وحفظ",
    "fr": "Arrêter et enregistrer",
    "hi": "रोकें और सहेजें",
    "ru": "Стоп и сохранить"
  },
  "video.button.startRecording": {
    "en": "Start recording",
    "zh-Hans": "开始录制",
    "zh-Hant": "開始錄製",
    "es": "Iniciar grabación",
    "pt": "Iniciar gravação",
    "ar": "بدء التسجيل",
    "fr": "Démarrer l’enregistrement",
    "hi": "रिकॉर्डिंग शुरू करें",
    "ru": "Начать запись"
  },
  "video.tips.watermarkTitle": {
    "en": "On-screen overlay",
    "zh-Hans": "画面叠加",
    "zh-Hant": "畫面疊加",
    "es": "Superposición en pantalla",
    "pt": "Sobreposição na tela",
    "ar": "تراكب على الشاشة",
    "fr": "Superposition à l’écran",
    "hi": "ऑन-स्क्रीन ओवरले",
    "ru": "Наложение на экране"
  },
  "video.tips.watermarkBody": {
    "en": "Decibel readings and GPS (when available) are burned into the video for evidence.",
    "zh-Hans": "分贝读数和 GPS（如可用）会嵌入视频作为证据。",
    "zh-Hant": "分貝讀數與 GPS（若可用）會嵌入影片作為證據。",
    "es": "Las lecturas en decibelios y el GPS (si está disponible) se incrustan en el vídeo como prueba.",
    "pt": "Leituras em decibéis e GPS (quando disponível) são gravadas no vídeo como prova.",
    "ar": "تُدمج قراءات الديسيبل وGPS (إن وُجد) في الفيديو كدليل.",
    "fr": "Les mesures en décibels et le GPS (si disponible) sont intégrés à la vidéo comme preuve.",
    "hi": "dB रीडिंग और GPS (यदि उपलब्ध) साक्ष्य के लिए वीडियो में जोड़े जाते हैं।",
    "ru": "Показания дБ и GPS (если доступно) встраиваются в видео как доказательство."
  },
  "video.error.monitoringStartFailed": {
    "en": "Could not start noise monitoring for video.",
    "zh-Hans": "无法为视频启动噪声监测。",
    "zh-Hant": "無法為影片啟動噪音監測。",
    "es": "No se pudo iniciar la monitorización de ruido para el vídeo.",
    "pt": "Não foi possível iniciar o monitoramento de ruído para o vídeo.",
    "ar": "تعذر بدء مراقبة الضوضاء للفيديو.",
    "fr": "Impossible de démarrer la surveillance du bruit pour la vidéo.",
    "hi": "वीडियो के लिए शोर मॉनिटरिंग शुरू नहीं हो सकी।",
    "ru": "Не удалось запустить мониторинг шума для видео."
  },
  "video.savedFile": {
    "en": "Saved: %1$@",
    "zh-Hans": "已保存：%1$@",
    "zh-Hant": "已儲存：%1$@",
    "es": "Guardado: %1$@",
    "pt": "Salvo: %1$@",
    "ar": "تم الحفظ: %1$@",
    "fr": "Enregistré : %1$@",
    "hi": "सहेजा गया: %1$@",
    "ru": "Сохранено: %1$@"
  },
  "files.title": {
    "en": "Files",
    "zh-Hans": "文件",
    "zh-Hant": "檔案",
    "es": "Archivos",
    "pt": "Arquivos",
    "ar": "ملفات",
    "fr": "Fichiers",
    "hi": "फ़ाइलें",
    "ru": "Файлы"
  },
  "files.tab.video": {
    "en": "Video",
    "zh-Hans": "视频",
    "zh-Hant": "影片",
    "es": "Vídeo",
    "pt": "Vídeo",
    "ar": "فيديو",
    "fr": "Vidéo",
    "hi": "वीडियो",
    "ru": "Видео"
  },
  "files.tab.voice": {
    "en": "Audio",
    "zh-Hans": "音频",
    "zh-Hant": "音訊",
    "es": "Audio",
    "pt": "Áudio",
    "ar": "صوت",
    "fr": "Audio",
    "hi": "ऑडियो",
    "ru": "Аудио"
  },
  "files.picker.type": {
    "en": "Type",
    "zh-Hans": "类型",
    "zh-Hant": "類型",
    "es": "Tipo",
    "pt": "Tipo",
    "ar": "النوع",
    "fr": "Type",
    "hi": "प्रकार",
    "ru": "Тип"
  },
  "files.picker.sort": {
    "en": "Sort",
    "zh-Hans": "排序",
    "zh-Hant": "排序",
    "es": "Ordenar",
    "pt": "Ordenar",
    "ar": "ترتيب",
    "fr": "Trier",
    "hi": "क्रमबद्ध करें",
    "ru": "Сортировка"
  },
  "files.sort.dateDescending": {
    "en": "Date (newest)",
    "zh-Hans": "日期（新到旧）",
    "zh-Hant": "日期（新到舊）",
    "es": "Fecha (más reciente)",
    "pt": "Data (mais recente)",
    "ar": "التاريخ (الأحدث)",
    "fr": "Date (plus récent)",
    "hi": "तिथि (नवीनतम)",
    "ru": "Дата (сначала новые)"
  },
  "files.sort.dateAscending": {
    "en": "Date (oldest)",
    "zh-Hans": "日期（旧到新）",
    "zh-Hant": "日期（舊到新）",
    "es": "Fecha (más antigua)",
    "pt": "Data (mais antiga)",
    "ar": "التاريخ (الأقدم)",
    "fr": "Date (plus ancien)",
    "hi": "तिथि (पुरानी)",
    "ru": "Дата (сначала старые)"
  },
  "files.sort.peakDescending": {
    "en": "Peak (high to low)",
    "zh-Hans": "峰值（高到低）",
    "zh-Hant": "峰值（高到低）",
    "es": "Pico (de mayor a menor)",
    "pt": "Pico (maior para menor)",
    "ar": "الذروة (من الأعلى)",
    "fr": "Pic (du plus au moins fort)",
    "hi": "पीक (उच्च से निम्न)",
    "ru": "Пик (по убыванию)"
  },
  "files.sort.peakAscending": {
    "en": "Peak (low to high)",
    "zh-Hans": "峰值（低到高）",
    "zh-Hant": "峰值（低到高）",
    "es": "Pico (de menor a mayor)",
    "pt": "Pico (menor para maior)",
    "ar": "الذروة (من الأدنى)",
    "fr": "Pic (du moins au plus fort)",
    "hi": "पीक (निम्न से उच्च)",
    "ru": "Пик (по возрастанию)"
  },
  "files.sort.nameAscending": {
    "en": "Name (A–Z)",
    "zh-Hans": "名称（A–Z）",
    "zh-Hant": "名稱（A–Z）",
    "es": "Nombre (A–Z)",
    "pt": "Nome (A–Z)",
    "ar": "الاسم (أ–ي)",
    "fr": "Nom (A–Z)",
    "hi": "नाम (A–Z)",
    "ru": "Имя (А–Я)"
  },
  "files.selection.select": {
    "en": "Select",
    "zh-Hans": "选择",
    "zh-Hant": "選取",
    "es": "Seleccionar",
    "pt": "Selecionar",
    "ar": "تحديد",
    "fr": "Sélectionner",
    "hi": "चुनें",
    "ru": "Выбрать"
  },
  "files.selection.selectAll": {
    "en": "Select all",
    "zh-Hans": "全选",
    "zh-Hant": "全選",
    "es": "Seleccionar todo",
    "pt": "Selecionar tudo",
    "ar": "تحديد الكل",
    "fr": "Tout sélectionner",
    "hi": "सभी चुनें",
    "ru": "Выбрать все"
  },
  "files.selection.deselectAll": {
    "en": "Deselect all",
    "zh-Hans": "取消全选",
    "zh-Hant": "取消全選",
    "es": "Deseleccionar todo",
    "pt": "Desmarcar tudo",
    "ar": "إلغاء تحديد الكل",
    "fr": "Tout désélectionner",
    "hi": "सभी हटाएँ",
    "ru": "Снять выделение"
  },
  "files.selection.count": {
    "en": "%d selected",
    "zh-Hans": "已选 %d 项",
    "zh-Hant": "已選 %d 項",
    "es": "%d seleccionados",
    "pt": "%d selecionados",
    "ar": "تم تحديد %d",
    "fr": "%d sélectionné(s)",
    "hi": "%d चयनित",
    "ru": "Выбрано: %d"
  },
  "files.summary.clips": {
    "en": "Clips",
    "zh-Hans": "片段",
    "zh-Hant": "片段",
    "es": "Clips",
    "pt": "Clipes",
    "ar": "مقاطع",
    "fr": "Clips",
    "hi": "क्लिप",
    "ru": "Клипы"
  },
  "files.summary.videos": {
    "en": "Videos",
    "zh-Hans": "视频",
    "zh-Hant": "影片",
    "es": "Vídeos",
    "pt": "Vídeos",
    "ar": "فيديوهات",
    "fr": "Vidéos",
    "hi": "वीडियो",
    "ru": "Видео"
  },
  "files.summary.duration": {
    "en": "Duration",
    "zh-Hans": "时长",
    "zh-Hant": "時長",
    "es": "Duración",
    "pt": "Duração",
    "ar": "المدة",
    "fr": "Durée",
    "hi": "अवधि",
    "ru": "Длительность"
  },
  "files.summary.peak": {
    "en": "Peak",
    "zh-Hans": "峰值",
    "zh-Hant": "峰值",
    "es": "Pico",
    "pt": "Pico",
    "ar": "الذروة",
    "fr": "Pic",
    "hi": "पीक",
    "ru": "Пик"
  },
  "files.badge.new": {
    "en": "New",
    "zh-Hans": "新",
    "zh-Hant": "新",
    "es": "Nuevo",
    "pt": "Novo",
    "ar": "جديد",
    "fr": "Nouveau",
    "hi": "नया",
    "ru": "Новое"
  },
  "files.badge.peakDb": {
    "en": "Peak %d dB",
    "zh-Hans": "峰值 %d dB",
    "zh-Hant": "峰值 %d dB",
    "es": "Pico %d dB",
    "pt": "Pico %d dB",
    "ar": "ذروة %d dB",
    "fr": "Pic %d dB",
    "hi": "पीक %d dB",
    "ru": "Пик %d dB"
  },
  "files.badge.avgDb": {
    "en": "Avg %d dB",
    "zh-Hans": "平均 %d dB",
    "zh-Hant": "平均 %d dB",
    "es": "Prom. %d dB",
    "pt": "Méd. %d dB",
    "ar": "متوسط %d dB",
    "fr": "Moy. %d dB",
    "hi": "औसत %d dB",
    "ru": "Сред. %d dB"
  },
  "files.empty.video.title": {
    "en": "No videos yet",
    "zh-Hans": "暂无视频",
    "zh-Hant": "尚無影片",
    "es": "Aún no hay vídeos",
    "pt": "Ainda não há vídeos",
    "ar": "لا توجد فيديوهات بعد",
    "fr": "Pas encore de vidéos",
    "hi": "अभी कोई वीडियो नहीं",
    "ru": "Видео пока нет"
  },
  "files.empty.video.message": {
    "en": "Record evidence video from the Video tab.",
    "zh-Hans": "在“视频”标签录制取证视频。",
    "zh-Hant": "在「影片」標籤錄製取證影片。",
    "es": "Graba vídeo de prueba desde la pestaña Vídeo.",
    "pt": "Grave vídeo de prova na aba Vídeo.",
    "ar": "سجّل فيديو دليلًا من تبويب الفيديو.",
    "fr": "Enregistrez une preuve vidéo depuis l’onglet Vidéo.",
    "hi": "वीडियो टैब से साक्ष्य वीडियो रिकॉर्ड करें।",
    "ru": "Запишите видеодоказательство во вкладке «Видео»."
  },
  "files.empty.audio.title": {
    "en": "No audio clips yet",
    "zh-Hans": "暂无音频",
    "zh-Hant": "尚無音訊",
    "es": "Aún no hay audio",
    "pt": "Ainda não há áudio",
    "ar": "لا توجد مقاطع صوتية بعد",
    "fr": "Pas encore d’audio",
    "hi": "अभी कोई ऑडियो नहीं",
    "ru": "Аудио пока нет"
  },
  "files.empty.audio.message": {
    "en": "Enable voice-activated recording on the Voice tab.",
    "zh-Hans": "在“语音”标签开启声控录音。",
    "zh-Hant": "在「語音」標籤開啟聲控錄音。",
    "es": "Activa la grabación por voz en la pestaña Voz.",
    "pt": "Ative a gravação por voz na aba Voz.",
    "ar": "فعّل التسجيل بالصوت في تبويب الصوت.",
    "fr": "Activez l’enregistrement vocal dans l’onglet Voix.",
    "hi": "वॉइस टैब पर वॉइस-सक्रिय रिकॉर्डिंग चालू करें।",
    "ru": "Включите голосовую запись во вкладке «Голос»."
  },
  "files.rename.alert.title": {
    "en": "Rename file",
    "zh-Hans": "重命名文件",
    "zh-Hant": "重新命名檔案",
    "es": "Renombrar archivo",
    "pt": "Renomear arquivo",
    "ar": "إعادة تسمية الملف",
    "fr": "Renommer le fichier",
    "hi": "फ़ाइल का नाम बदलें",
    "ru": "Переименовать файл"
  },
  "files.rename.field.placeholder": {
    "en": "File name",
    "zh-Hans": "文件名",
    "zh-Hant": "檔名",
    "es": "Nombre de archivo",
    "pt": "Nome do arquivo",
    "ar": "اسم الملف",
    "fr": "Nom du fichier",
    "hi": "फ़ाइल नाम",
    "ru": "Имя файла"
  },
  "files.rename.alert.message": {
    "en": "Enter a new name for this file.",
    "zh-Hans": "为此文件输入新名称。",
    "zh-Hant": "為此檔案輸入新名稱。",
    "es": "Introduce un nuevo nombre para este archivo.",
    "pt": "Digite um novo nome para este arquivo.",
    "ar": "أدخل اسمًا جديدًا لهذا الملف.",
    "fr": "Saisissez un nouveau nom pour ce fichier.",
    "hi": "इस फ़ाइल के लिए नया नाम दर्ज करें।",
    "ru": "Введите новое имя для этого файла."
  },
  "files.playback.error.title": {
    "en": "Playback error",
    "zh-Hans": "播放错误",
    "zh-Hant": "播放錯誤",
    "es": "Error de reproducción",
    "pt": "Erro de reprodução",
    "ar": "خطأ في التشغيل",
    "fr": "Erreur de lecture",
    "hi": "प्लेबैक त्रुटि",
    "ru": "Ошибка воспроизведения"
  },
  "files.delete.confirm.title": {
    "en": "Delete %d items?",
    "zh-Hans": "删除 %d 项？",
    "zh-Hant": "刪除 %d 項？",
    "es": "¿Eliminar %d elementos?",
    "pt": "Excluir %d itens?",
    "ar": "حذف %d عناصر؟",
    "fr": "Supprimer %d éléments ?",
    "hi": "%d आइटम हटाएँ?",
    "ru": "Удалить элементов: %d?"
  },
  "files.error.videoNotFound": {
    "en": "Video file not found: %1$@",
    "zh-Hans": "未找到视频文件：%1$@",
    "zh-Hant": "找不到影片檔案：%1$@",
    "es": "Archivo de vídeo no encontrado: %1$@",
    "pt": "Arquivo de vídeo não encontrado: %1$@",
    "ar": "ملف الفيديو غير موجود: %1$@",
    "fr": "Fichier vidéo introuvable : %1$@",
    "hi": "वीडियो फ़ाइल नहीं मिली: %1$@",
    "ru": "Видеофайл не найден: %1$@"
  },
  "files.error.audioNotFound": {
    "en": "Audio file not found: %1$@",
    "zh-Hans": "未找到音频文件：%1$@",
    "zh-Hant": "找不到音訊檔案：%1$@",
    "es": "Archivo de audio no encontrado: %1$@",
    "pt": "Arquivo de áudio não encontrado: %1$@",
    "ar": "ملف الصوت غير موجود: %1$@",
    "fr": "Fichier audio introuvable : %1$@",
    "hi": "ऑडियो फ़ाइल नहीं मिली: %1$@",
    "ru": "Аудиофайл не найден: %1$@"
  },
  "files.audio.detailLine": {
    "en": "%1$@ · %2$llds",
    "zh-Hans": "%1$@ · %2$lld 秒",
    "zh-Hant": "%1$@ · %2$lld 秒",
    "es": "%1$@ · %2$lld s",
    "pt": "%1$@ · %2$lld s",
    "ar": "%1$@ · %2$lld ث",
    "fr": "%1$@ · %2$lld s",
    "hi": "%1$@ · %2$lld सेकंड",
    "ru": "%1$@ · %2$lld с"
  },
  "settings.title": {
    "en": "Settings",
    "zh-Hans": "设置",
    "zh-Hant": "設定",
    "es": "Ajustes",
    "pt": "Ajustes",
    "ar": "الإعدادات",
    "fr": "Réglages",
    "hi": "सेटिंग्स",
    "ru": "Настройки"
  },
  "settings.measurementMode.header": {
    "en": "Measurement mode",
    "zh-Hans": "测量模式",
    "zh-Hant": "測量模式",
    "es": "Modo de medición",
    "pt": "Modo de medição",
    "ar": "وضع القياس",
    "fr": "Mode de mesure",
    "hi": "मापन मोड",
    "ru": "Режим измерения"
  },
  "settings.weighting.header": {
    "en": "Frequency weighting",
    "zh-Hans": "频率计权",
    "zh-Hant": "頻率計權",
    "es": "Ponderación de frecuencia",
    "pt": "Ponderação de frequência",
    "ar": "ترجيح التردد",
    "fr": "Pondération fréquentielle",
    "hi": "आवृत्ति भारण",
    "ru": "Частотное взвешивание"
  },
  "settings.weighting.footer": {
    "en": "A-weighting matches human hearing; C and Z are used for technical and full-band analysis.",
    "zh-Hans": "A 计权贴近人耳听感；C 与 Z 用于技术与全频段分析。",
    "zh-Hant": "A 計權貼近人耳聽感；C 與 Z 用於技術與全頻段分析。",
    "es": "La ponderación A se aproxima a la audición humana; C y Z se usan para análisis técnico y de banda completa.",
    "pt": "A ponderação A aproxima a audição humana; C e Z são usadas para análise técnica e de banda completa.",
    "ar": "الترجيح A يقارب السمع البشري؛ يُستخدمان C وZ للتحليل التقني وكامل النطاق.",
    "fr": "La pondération A suit l’audition humaine ; C et Z servent à l’analyse technique et pleine bande.",
    "hi": "A-भारण मानव श्रवण के करीब है; C और Z तकनीकी/पूर्ण-बैंड विश्लेषण के लिए।",
    "ru": "A-взвешивание близко к слуху человека; C и Z — для технического и полнополосного анализа."
  },
  "settings.weighting.picker.label": {
    "en": "Weighting",
    "zh-Hans": "计权",
    "zh-Hant": "計權",
    "es": "Ponderación",
    "pt": "Ponderação",
    "ar": "الترجيح",
    "fr": "Pondération",
    "hi": "भारण",
    "ru": "Взвешивание"
  },
  "settings.calibration.header": {
    "en": "Device calibration",
    "zh-Hans": "设备校准",
    "zh-Hant": "裝置校準",
    "es": "Calibración del dispositivo",
    "pt": "Calibração do dispositivo",
    "ar": "معايرة الجهاز",
    "fr": "Étalonnage de l’appareil",
    "hi": "डिवाइस कैलिब्रेशन",
    "ru": "Калибровка устройства"
  },
  "settings.calibration.footer": {
    "en": "Mode offset baseline is 115–118 dB; a quiet room should read about 30–40 dB. Fine-tune with a professional meter if needed.",
    "zh-Hans": "模式偏移基线约为 115–118 dB；安静房间读数约 30–40 dB。如有需要请用专业声级计微调。",
    "zh-Hant": "模式偏移基線約為 115–118 dB；安靜房間讀數約 30–40 dB。如有需要請用專業聲級計微調。",
    "es": "La línea base de offset del modo es 115–118 dB; una habitación tranquila debería marcar unos 30–40 dB. Ajusta con un sonómetro profesional si hace falta.",
    "pt": "A linha de base de offset do modo é 115–118 dB; um ambiente silencioso deve marcar cerca de 30–40 dB. Ajuste com um medidor profissional se necessário.",
    "ar": "خط الأساس لإزاحة الوضع 115–118 dB؛ يجب أن تقرأ غرفة هادئة نحو 30–40 dB. اضبط بمقياس احترافي عند الحاجة.",
    "fr": "La base d’offset du mode est de 115–118 dB ; une pièce calme devrait afficher environ 30–40 dB. Ajustez avec un sonomètre pro si besoin.",
    "hi": "मोड ऑफ़सेट बेसलाइन 115–118 dB है; शांत कमरे में लगभग 30–40 dB दिखना चाहिए। ज़रूरत हो तो प्रो मीटर से फाइन-ट्यून करें।",
    "ru": "Базовое смещение режима 115–118 dB; в тихой комнате должно быть около 30–40 dB. При необходимости подстройте профессиональным шумомером."
  },
  "settings.calibration.currentMode": {
    "en": "Current mode",
    "zh-Hans": "当前模式",
    "zh-Hant": "目前模式",
    "es": "Modo actual",
    "pt": "Modo atual",
    "ar": "الوضع الحالي",
    "fr": "Mode actuel",
    "hi": "वर्तमान मोड",
    "ru": "Текущий режим"
  },
  "settings.calibration.technicalBadge": {
    "en": "Technical",
    "zh-Hans": "技术",
    "zh-Hant": "技術",
    "es": "Técnico",
    "pt": "Técnico",
    "ar": "تقني",
    "fr": "Technique",
    "hi": "तकनीकी",
    "ru": "Техн."
  },
  "settings.calibration.deviceModel": {
    "en": "Device model",
    "zh-Hans": "设备型号",
    "zh-Hant": "裝置型號",
    "es": "Modelo del dispositivo",
    "pt": "Modelo do dispositivo",
    "ar": "طراز الجهاز",
    "fr": "Modèle d’appareil",
    "hi": "डिवाइस मॉडल",
    "ru": "Модель устройства"
  },
  "settings.calibration.deviceOffset": {
    "en": "Device offset",
    "zh-Hans": "设备偏移",
    "zh-Hant": "裝置偏移",
    "es": "Offset del dispositivo",
    "pt": "Offset do dispositivo",
    "ar": "إزاحة الجهاز",
    "fr": "Offset appareil",
    "hi": "डिवाइस ऑफ़सेट",
    "ru": "Смещение устройства"
  },
  "settings.calibration.userAdjustment": {
    "en": "User adjustment",
    "zh-Hans": "用户调整",
    "zh-Hant": "使用者調整",
    "es": "Ajuste del usuario",
    "pt": "Ajuste do usuário",
    "ar": "تعديل المستخدم",
    "fr": "Ajustement utilisateur",
    "hi": "उपयोगकर्ता समायोजन",
    "ru": "Пользовательская поправка"
  },
  "settings.calibration.totalOffset": {
    "en": "Total offset",
    "zh-Hans": "总偏移",
    "zh-Hant": "總偏移",
    "es": "Offset total",
    "pt": "Offset total",
    "ar": "إجمالي الإزاحة",
    "fr": "Offset total",
    "hi": "कुल ऑफ़सेट",
    "ru": "Суммарное смещение"
  },
  "settings.calibration.rmsFloor": {
    "en": "RMS floor",
    "zh-Hans": "RMS 底噪",
    "zh-Hant": "RMS 底噪",
    "es": "Piso RMS",
    "pt": "Piso RMS",
    "ar": "أرضية RMS",
    "fr": "Plancher RMS",
    "hi": "RMS फ़्लोर",
    "ru": "Порог RMS"
  },
  "settings.calibration.calibrateButton": {
    "en": "Calibrate",
    "zh-Hans": "校准",
    "zh-Hant": "校準",
    "es": "Calibrar",
    "pt": "Calibrar",
    "ar": "معايرة",
    "fr": "Étalonner",
    "hi": "कैलिब्रेट करें",
    "ru": "Калибровать"
  },
  "settings.calibration.resetButton": {
    "en": "Reset calibration",
    "zh-Hans": "重置校准",
    "zh-Hant": "重置校準",
    "es": "Restablecer calibración",
    "pt": "Redefinir calibração",
    "ar": "إعادة ضبط المعايرة",
    "fr": "Réinitialiser l’étalonnage",
    "hi": "कैलिब्रेशन रीसेट",
    "ru": "Сбросить калибровку"
  },
  "settings.calibration.alert.saved.title": {
    "en": "Calibration saved",
    "zh-Hans": "校准已保存",
    "zh-Hant": "校準已儲存",
    "es": "Calibración guardada",
    "pt": "Calibração salva",
    "ar": "تم حفظ المعايرة",
    "fr": "Étalonnage enregistré",
    "hi": "कैलिब्रेशन सहेजा गया",
    "ru": "Калибровка сохранена"
  },
  "settings.calibration.referenceLevel": {
    "en": "Reference level: %d dB",
    "zh-Hans": "参考声级：%d dB",
    "zh-Hant": "參考聲級：%d dB",
    "es": "Nivel de referencia: %d dB",
    "pt": "Nível de referência: %d dB",
    "ar": "مستوى المرجع: %d dB",
    "fr": "Niveau de référence : %d dB",
    "hi": "संदर्भ स्तर: %d dB",
    "ru": "Опорный уровень: %d dB"
  },
  "settings.calibration.reset.alert.alreadyDefault.title": {
    "en": "Already at factory default",
    "zh-Hans": "已是出厂默认",
    "zh-Hant": "已是出廠預設",
    "es": "Ya está en valores de fábrica",
    "pt": "Já está no padrão de fábrica",
    "ar": "بالفعل على الإعداد الافتراضي",
    "fr": "Déjà aux réglages d’usine",
    "hi": "पहले से फ़ैक्टरी डिफ़ॉल्ट पर",
    "ru": "Уже заводские настройки"
  },
  "settings.calibration.reset.alert.restored.title": {
    "en": "Factory calibration restored",
    "zh-Hans": "已恢复出厂校准",
    "zh-Hant": "已恢復出廠校準",
    "es": "Calibración de fábrica restaurada",
    "pt": "Calibração de fábrica restaurada",
    "ar": "تمت استعادة معايرة المصنع",
    "fr": "Étalonnage d’usine rétabli",
    "hi": "फ़ैक्टरी कैलिब्रेशन बहाल",
    "ru": "Заводская калибровка восстановлена"
  },
  "settings.calibration.alert.saved.small": {
    "en": "Calibration saved. The adjustment was very small.\\n\\nUser adjustment: %1$@\\nTotal offset: %2$@\\n\\nKeep monitoring and compare against your sound level meter.",
    "zh-Hans": "校准已保存。调整幅度很小。\\n\\n用户调整：%1$@\\n总偏移：%2$@\\n\\n请继续监测并与声级计对比。",
    "zh-Hant": "校準已儲存。調整幅度很小。\\n\\n使用者調整：%1$@\\n總偏移：%2$@\\n\\n請繼續監測並與聲級計比對。",
    "es": "Calibración guardada. El ajuste fue muy pequeño.\\n\\nAjuste del usuario: %1$@\\nOffset total: %2$@\\n\\nSigue monitorizando y compáralo con tu sonómetro.",
    "pt": "Calibração salva. O ajuste foi muito pequeno.\\n\\nAjuste do usuário: %1$@\\nOffset total: %2$@\\n\\nContinue monitorando e compare com seu decibelímetro.",
    "ar": "تم حفظ المعايرة. كان التعديل صغيرًا جدًا.\\n\\nتعديل المستخدم: %1$@\\nإجمالي الإزاحة: %2$@\\n\\nتابع المراقبة وقارن بمقياس الصوت.",
    "fr": "Étalonnage enregistré. L’ajustement était très faible.\\n\\nAjustement utilisateur : %1$@\\nOffset total : %2$@\\n\\nContinuez la surveillance et comparez avec votre sonomètre.",
    "hi": "कैलिब्रेशन सहेजा गया। समायोजन बहुत छोटा था।\\n\\nउपयोगकर्ता समायोजन: %1$@\\nकुल ऑफ़सेट: %2$@\\n\\nमॉनिटरिंग जारी रखें और साउंड लेवल मीटर से तुलना करें।",
    "ru": "Калибровка сохранена. Поправка была очень небольшой.\\n\\nПользовательская поправка: %1$@\\nСуммарное смещение: %2$@\\n\\nПродолжайте мониторинг и сравнивайте с шумомером."
  },
  "settings.calibration.alert.saved.changed": {
    "en": "Calibrated to reference level %1$d dB.\\n\\nUser adjustment: %2$@ → %3$@\\nTotal offset: %4$@\\n\\nMonitor readings will use the new baseline.",
    "zh-Hans": "已校准至参考声级 %1$d dB。\\n\\n用户调整：%2$@ → %3$@\\n总偏移：%4$@\\n\\n监测读数将使用新基线。",
    "zh-Hant": "已校準至參考聲級 %1$d dB。\\n\\n使用者調整：%2$@ → %3$@\\n總偏移：%4$@\\n\\n監測讀數將使用新基線。",
    "es": "Calibrado al nivel de referencia %1$d dB.\\n\\nAjuste del usuario: %2$@ → %3$@\\nOffset total: %4$@\\n\\nLas lecturas usarán la nueva línea base.",
    "pt": "Calibrado para o nível de referência %1$d dB.\\n\\nAjuste do usuário: %2$@ → %3$@\\nOffset total: %4$@\\n\\nAs leituras usarão a nova linha de base.",
    "ar": "تمت المعايرة إلى مستوى المرجع %1$d dB.\\n\\nتعديل المستخدم: %2$@ → %3$@\\nإجمالي الإزاحة: %4$@\\n\\nستستخدم القراءات خط الأساس الجديد.",
    "fr": "Étalonné au niveau de référence %1$d dB.\\n\\nAjustement utilisateur : %2$@ → %3$@\\nOffset total : %4$@\\n\\nLes mesures utiliseront la nouvelle base.",
    "hi": "%1$d dB संदर्भ स्तर पर कैलिब्रेट किया गया।\\n\\nउपयोगकर्ता समायोजन: %2$@ → %3$@\\nकुल ऑफ़सेट: %4$@\\n\\nरीडिंग नई बेसलाइन का उपयोग करेंगी।",
    "ru": "Калибровка по опорному уровню %1$d dB.\\n\\nПользовательская поправка: %2$@ → %3$@\\nСуммарное смещение: %4$@\\n\\nПоказания будут использовать новую базу."
  },
  "settings.calibration.reset.alert.alreadyDefault.message": {
    "en": "No manual adjustment was set; nothing to reset.\\n\\nUser adjustment: 0 dB (no extra offset)\\nTotal offset: %@\\n\\nA quiet room should read about 30–40 dB.",
    "zh-Hans": "未设置手动调整，无需重置。\\n\\n用户调整：0 dB（无额外偏移）\\n总偏移：%@\\n\\n安静房间读数约 30–40 dB。",
    "zh-Hant": "未設定手動調整，無需重置。\\n\\n使用者調整：0 dB（無額外偏移）\\n總偏移：%@\\n\\n安靜房間讀數約 30–40 dB。",
    "es": "No había ajuste manual; nada que restablecer.\\n\\nAjuste del usuario: 0 dB (sin offset extra)\\nOffset total: %@\\n\\nUna habitación tranquila debería marcar unos 30–40 dB.",
    "pt": "Nenhum ajuste manual definido; nada a redefinir.\\n\\nAjuste do usuário: 0 dB (sem offset extra)\\nOffset total: %@\\n\\nUm ambiente silencioso deve marcar cerca de 30–40 dB.",
    "ar": "لم يُضبط تعديل يدوي؛ لا شيء لإعادة الضبط.\\n\\nتعديل المستخدم: 0 dB (بدون إزاحة إضافية)\\nإجمالي الإزاحة: %@\\n\\nيجب أن تقرأ غرفة هادئة نحو 30–40 dB.",
    "fr": "Aucun ajustement manuel ; rien à réinitialiser.\\n\\nAjustement utilisateur : 0 dB (pas d’offset)\\nOffset total : %@\\n\\nUne pièce calme devrait afficher environ 30–40 dB.",
    "hi": "कोई मैनुअल समायोजन नहीं था; रीसेट करने को कुछ नहीं।\\n\\nउपयोगकर्ता समायोजन: 0 dB (कोई अतिरिक्त ऑफ़सेट नहीं)\\nकुल ऑफ़सेट: %@\\n\\nशांत कमरे में लगभग 30–40 dB दिखना चाहिए।",
    "ru": "Ручная поправка не задана; сбрасывать нечего.\\n\\nПользовательская поправка: 0 dB (без доп. смещения)\\nСуммарное смещение: %@\\n\\nВ тихой комнате должно быть около 30–40 dB."
  },
  "settings.calibration.reset.alert.restored.message": {
    "en": "Cleared your manual adjustment (%1$@).\\n\\nTotal offset: %2$@ → %3$@\\nUser adjustment: %4$@ → 0 dB\\n\\nMonitor readings return to factory defaults. Recalibrate with a meter if needed.",
    "zh-Hans": "已清除手动调整（%1$@）。\\n\\n总偏移：%2$@ → %3$@\\n用户调整：%4$@ → 0 dB\\n\\n监测读数恢复出厂默认。如有需要请重新校准。",
    "zh-Hant": "已清除手動調整（%1$@）。\\n\\n總偏移：%2$@ → %3$@\\n使用者調整：%4$@ → 0 dB\\n\\n監測讀數恢復出廠預設。如有需要請重新校準。",
    "es": "Se eliminó tu ajuste manual (%1$@).\\n\\nOffset total: %2$@ → %3$@\\nAjuste del usuario: %4$@ → 0 dB\\n\\nLas lecturas vuelven a valores de fábrica. Recalibra con un medidor si hace falta.",
    "pt": "Seu ajuste manual (%1$@) foi removido.\\n\\nOffset total: %2$@ → %3$@\\nAjuste do usuário: %4$@ → 0 dB\\n\\nAs leituras voltam ao padrão de fábrica. Recalibre com um medidor se necessário.",
    "ar": "تم مسح تعديلك اليدوي (%1$@).\\n\\nإجمالي الإزاحة: %2$@ → %3$@\\nتعديل المستخدم: %4$@ → 0 dB\\n\\nتعود القراءات إلى الإعداد الافتراضي. أعد المعايرة بمقياس عند الحاجة.",
    "fr": "Votre ajustement manuel (%1$@) a été effacé.\\n\\nOffset total : %2$@ → %3$@\\nAjustement utilisateur : %4$@ → 0 dB\\n\\nLes mesures reviennent aux réglages d’usine. Réétalonnez si besoin.",
    "hi": "आपका मैनुअल समायोजन (%1$@) हटाया गया।\\n\\nकुल ऑफ़सेट: %2$@ → %3$@\\nउपयोगकर्ता समायोजन: %4$@ → 0 dB\\n\\nरीडिंग फ़ैक्टरी डिफ़ॉल्ट पर लौटती हैं। ज़रूरत हो तो मीटर से फिर कैलिब्रेट करें।",
    "ru": "Ручная поправка (%1$@) сброшена.\\n\\nСуммарное смещение: %2$@ → %3$@\\nПользовательская поправка: %4$@ → 0 dB\\n\\nПоказания возвращаются к заводским. При необходимости откалибруйте снова."
  },
  "modeGuide.title": {
    "en": "Mode Guide",
    "zh-Hans": "模式指南",
    "zh-Hant": "模式指南",
    "es": "Guía de modos",
    "pt": "Guia de modos",
    "ar": "دليل الأوضاع",
    "fr": "Guide des modes",
    "hi": "मोड गाइड",
    "ru": "Справка по режимам"
  },
  "modeGuide.section.whatDoesItDo": {
    "en": "What does this mode do?",
    "zh-Hans": "此模式做什么？",
    "zh-Hant": "此模式做什麼？",
    "es": "¿Qué hace este modo?",
    "pt": "O que este modo faz?",
    "ar": "ماذا يفعل هذا الوضع؟",
    "fr": "Que fait ce mode ?",
    "hi": "यह मोड क्या करता है?",
    "ru": "Что делает этот режим?"
  },
  "modeGuide.section.details": {
    "en": "Details",
    "zh-Hans": "详情",
    "zh-Hant": "詳情",
    "es": "Detalles",
    "pt": "Detalhes",
    "ar": "التفاصيل",
    "fr": "Détails",
    "hi": "विवरण",
    "ru": "Подробности"
  },
  "modeGuide.section.whyDifferent": {
    "en": "Why do the two modes read so differently?",
    "zh-Hans": "两种模式读数为何差很多？",
    "zh-Hant": "兩種模式讀數為何差很多？",
    "es": "¿Por qué los dos modos marcan tan distinto?",
    "pt": "Por que os dois modos leem tão diferente?",
    "ar": "لماذا تختلف قراءات الوضعين كثيرًا؟",
    "fr": "Pourquoi les deux modes affichent-ils des valeurs si différentes ?",
    "hi": "दोनों मोड की रीडिंग इतनी अलग क्यों?",
    "ru": "Почему показания двух режимов так отличаются?"
  },
  "modeGuide.section.whichMode": {
    "en": "Which mode should I use?",
    "zh-Hans": "该用哪种模式？",
    "zh-Hant": "該用哪種模式？",
    "es": "¿Qué modo debo usar?",
    "pt": "Qual modo devo usar?",
    "ar": "أي وضع يجب أن أستخدم؟",
    "fr": "Quel mode utiliser ?",
    "hi": "कौन सा मोड उपयोग करूँ?",
    "ru": "Какой режим выбрать?"
  },
  "modeGuide.comparison.standard.summary": {
    "en": "Daily noise, neighbor disputes, noise standards",
    "zh-Hans": "日常噪声、邻里纠纷、噪声标准",
    "zh-Hant": "日常噪音、鄰里糾紛、噪音標準",
    "es": "Ruido diario, disputas vecinales, normas de ruido",
    "pt": "Ruído diário, disputas com vizinhos, normas de ruído",
    "ar": "ضوضاء يومية، نزاعات الجيران، معايير الضوضاء",
    "fr": "Bruit quotidien, voisinage, normes sonores",
    "hi": "दैनिक शोर, पड़ोस विवाद, शोर मानक",
    "ru": "Повседневный шум, соседи, нормы"
  },
  "modeGuide.comparison.highSensitivity.summary": {
    "en": "Hidden low-frequency noise, machine faults, night evidence",
    "zh-Hans": "隐蔽低频噪声、设备故障、夜间取证",
    "zh-Hant": "隱蔽低頻噪音、設備故障、夜間取證",
    "es": "Ruido grave oculto, fallos de máquinas, pruebas nocturnas",
    "pt": "Ruído grave oculto, falhas de máquinas, provas noturnas",
    "ar": "ضوضاء منخفضة التردد الخفية، أعطال الآلات، أدلة ليلية",
    "fr": "Bruit grave caché, pannes machines, preuves de nuit",
    "hi": "छिपा निम्न-आवृत्ति शोर, मशीन खराबी, रात्रि साक्ष्य",
    "ru": "Скрытый НЧ-шум, неисправности, ночные доказательства"
  },
  "modeSwitch.title": {
    "en": "Measurement mode",
    "zh-Hans": "测量模式",
    "zh-Hant": "測量模式",
    "es": "Modo de medición",
    "pt": "Modo de medição",
    "ar": "وضع القياس",
    "fr": "Mode de mesure",
    "hi": "मापन मोड",
    "ru": "Режим измерения"
  },
  "modeSwitch.accessibility.modeExplanation": {
    "en": "Opens mode explanation",
    "zh-Hans": "打开模式说明",
    "zh-Hant": "開啟模式說明",
    "es": "Abre la explicación del modo",
    "pt": "Abre a explicação do modo",
    "ar": "يفتح شرح الوضع",
    "fr": "Ouvre l’explication du mode",
    "hi": "मोड व्याख्या खोलता है",
    "ru": "Открывает описание режима"
  },
  "modeSwitch.learnMore": {
    "en": "Learn more",
    "zh-Hans": "了解更多",
    "zh-Hant": "了解更多",
    "es": "Más información",
    "pt": "Saiba mais",
    "ar": "اعرف المزيد",
    "fr": "En savoir plus",
    "hi": "और जानें",
    "ru": "Подробнее"
  },
  "mode.standard.userFacingTitle": {
    "en": "Human Hearing Mode",
    "zh-Hans": "人耳听感模式",
    "zh-Hant": "人耳聽感模式",
    "es": "Modo audición humana",
    "pt": "Modo audição humana",
    "ar": "وضع السمع البشري",
    "fr": "Mode audition humaine",
    "hi": "मानव श्रवण मोड",
    "ru": "Режим слуха человека"
  },
  "mode.standard.userFacingSubtitle": {
    "en": "Everyday listening assessment",
    "zh-Hans": "日常听感评估",
    "zh-Hant": "日常聽感評估",
    "es": "Evaluación auditiva cotidiana",
    "pt": "Avaliação auditiva do dia a dia",
    "ar": "تقييم الاستماع اليومي",
    "fr": "Évaluation auditive quotidienne",
    "hi": "दैनिक श्रवण मूल्यांकन",
    "ru": "Повседневная оценка на слух"
  },
  "mode.standard.segmentLabel": {
    "en": "Standard",
    "zh-Hans": "标准",
    "zh-Hant": "標準",
    "es": "Estándar",
    "pt": "Padrão",
    "ar": "قياسي",
    "fr": "Standard",
    "hi": "मानक",
    "ru": "Стандарт"
  },
  "mode.standard.technicalBadge": {
    "en": "dBA",
    "zh-Hans": "dBA",
    "zh-Hant": "dBA",
    "es": "dBA",
    "pt": "dBA",
    "ar": "dBA",
    "fr": "dBA",
    "hi": "dBA",
    "ru": "dBA"
  },
  "mode.standard.coreDescription": {
    "en": "Simulates how the human ear perceives sound, filtering frequencies we are less sensitive to.",
    "zh-Hans": "模拟人耳对声音的感知，滤除较不敏感的频率。",
    "zh-Hant": "模擬人耳對聲音的感知，濾除較不敏感的頻率。",
    "es": "Simula cómo percibe el oído humano el sonido, filtrando frecuencias a las que somos menos sensibles.",
    "pt": "Simula como o ouvido humano percebe o som, filtrando frequências às quais somos menos sensíveis.",
    "ar": "يحاكي إدراك الأذن البشرية للصوت، مع ترشيح الترددات الأقل حساسية.",
    "fr": "Simule la perception sonore de l’oreille humaine en filtrant les fréquences moins sensibles.",
    "hi": "मानव कान की ध्वनि अनुभूति की नकल करता है, कम संवेदनशील आवृत्तियाँ छानता है।",
    "ru": "Имитирует восприятие звука ухом, отфильтровывая менее чувствительные частоты."
  },
  "mode.standard.tooltipCopy": {
    "en": "[Standard] Closest to subjective hearing. Best for everyday speech, TV noise, mall crowds, or neighbor disputes. Residential noise standards (e.g. 45 dB at night) are based on this mode.",
    "zh-Hans": "【标准】最接近主观听感。适合日常说话、电视声、商场人群或邻里纠纷。住宅噪声标准（如夜间 45 dB）基于此模式。",
    "zh-Hant": "【標準】最接近主觀聽感。適合日常說話、電視聲、商場人群或鄰里糾紛。住宅噪音標準（如夜間 45 dB）基於此模式。",
    "es": "[Estándar] Lo más cercano a la audición subjetiva. Ideal para voz cotidiana, TV, multitudes o disputas vecinales. Las normas residenciales (p. ej. 45 dB de noche) se basan en este modo.",
    "pt": "[Padrão] Mais próximo da audição subjetiva. Ideal para fala diária, TV, multidões ou disputas com vizinhos. Normas residenciais (ex.: 45 dB à noite) usam este modo.",
    "ar": "[قياسي] الأقرب للسمع الذاتي. مناسب للكلام اليومي وضوضاء التلفاز والحشود أو نزاعات الجيران. معايير الضوضاء السكنية (مثل 45 dB ليلًا) مبنية على هذا الوضع.",
    "fr": "[Standard] Proche de l’audition subjective. Idéal pour la parole, la TV, les foules ou les voisins. Les normes résidentielles (ex. 45 dB la nuit) reposent sur ce mode.",
    "hi": "[मानक] व्यक्तिपरक श्रवण के सबसे करीब। रोज़मर्रा की बातचीत, TV, भीड़ या पड़ोस विवाद के लिए। आवासीय मानक (जैसे रात में 45 dB) इसी पर आधारित।",
    "ru": "[Стандарт] Ближе всего к субъективному слуху. Для речи, ТВ, толпы, соседей. Жилые нормы (напр. 45 dB ночью) основаны на этом режиме."
  },
  "mode.standard.tooltipHeadline": {
    "en": "[Standard]",
    "zh-Hans": "【标准】",
    "zh-Hant": "【標準】",
    "es": "[Estándar]",
    "pt": "[Padrão]",
    "ar": "[قياسي]",
    "fr": "[Standard]",
    "hi": "[मानक]",
    "ru": "[Стандарт]"
  },
  "mode.standard.comparisonHint": {
    "en": "Readings match how loud it sounds to you—useful for comparing against noise standards.",
    "zh-Hans": "读数贴近您感受到的响度，便于对照噪声标准。",
    "zh-Hant": "讀數貼近您感受到的響度，便於對照噪音標準。",
    "es": "Las lecturas coinciden con lo fuerte que suena—útil para comparar con normas.",
    "pt": "As leituras correspondem ao que você ouve—útil para comparar com normas.",
    "ar": "القراءات تطابق مدى علو الصوت لديك—مفيدة للمقارنة بالمعايير.",
    "fr": "Les mesures reflètent le volume ressenti—utile pour les normes.",
    "hi": "रीडिंग आपको जितना तेज़ लगता है उसके करीब—मानक से तुलना के लिए उपयोगी।",
    "ru": "Показания соответствуют субъективной громкости—удобно сравнивать с нормами."
  },
  "mode.highSensitivity.userFacingTitle": {
    "en": "Full-Band / Low-Frequency",
    "zh-Hans": "全频段 / 低频",
    "zh-Hant": "全頻段 / 低頻",
    "es": "Banda completa / Graves",
    "pt": "Banda completa / Graves",
    "ar": "نطاق كامل / ترددات منخفضة",
    "fr": "Pleine bande / Graves",
    "hi": "पूर्ण-बैंड / निम्न-आवृत्ति",
    "ru": "Полная полоса / НЧ"
  },
  "mode.highSensitivity.userFacingSubtitle": {
    "en": "Physical sound pressure",
    "zh-Hans": "物理声压",
    "zh-Hant": "物理聲壓",
    "es": "Presión sonora física",
    "pt": "Pressão sonora física",
    "ar": "ضغط الصوت الفيزيائي",
    "fr": "Pression acoustique physique",
    "hi": "भौतिक ध्वनि दबाव",
    "ru": "Физическое звуковое давление"
  },
  "mode.highSensitivity.segmentLabel": {
    "en": "High Sensitivity",
    "zh-Hans": "高灵敏度",
    "zh-Hant": "高靈敏度",
    "es": "Alta sensibilidad",
    "pt": "Alta sensibilidade",
    "ar": "حساسية عالية",
    "fr": "Haute sensibilité",
    "hi": "उच्च संवेदनशीलता",
    "ru": "Высокая чувствительность"
  },
  "mode.highSensitivity.technicalBadge": {
    "en": "dBZ / dBC",
    "zh-Hans": "dBZ / dBC",
    "zh-Hant": "dBZ / dBC",
    "es": "dBZ / dBC",
    "pt": "dBZ / dBC",
    "ar": "dBZ / dBC",
    "fr": "dBZ / dBC",
    "hi": "dBZ / dBC",
    "ru": "dBZ / dBC"
  },
  "mode.highSensitivity.coreDescription": {
    "en": "Disables hearing-weighted filters and system noise suppression to capture full physical sound energy.",
    "zh-Hans": "关闭听感计权滤波与系统降噪，以捕捉完整物理声能。",
    "zh-Hant": "關閉聽感計權濾波與系統降噪，以捕捉完整物理聲能。",
    "es": "Desactiva filtros de audición y supresión de ruido del sistema para captar toda la energía sonora física.",
    "pt": "Desativa filtros de audição e supressão de ruído do sistema para capturar toda a energia sonora física.",
    "ar": "يعطّل مرشحات السمع وقمع ضوضاء النظام لالتقاط طاقة الصوت الفيزيائية كاملة.",
    "fr": "Désactive les filtres d’audition et la suppression système pour capturer toute l’énergie acoustique physique.",
    "hi": "श्रवण-भारित फ़िल्टर और सिस्टम शोर दमन बंद कर पूर्ण भौतिक ध्वनि ऊर्जा पकड़ता है।",
    "ru": "Отключает слуховые фильтры и подавление шума системы для полной физической энергии звука."
  },
  "mode.highSensitivity.tooltipCopy": {
    "en": "[High Sensitivity] Captures true physical energy in the air. In a quiet room at night it can pick up AC units, fridge compressors, and pipe rumble you may not notice. Readings are usually higher—ideal for hidden noise sources, machine faults, and evidence.",
    "zh-Hans": "【高灵敏度】捕捉空气中的真实物理能量。夜间安静房间可测到空调、冰箱压缩机、管道轰鸣等不易察觉的声音。读数通常更高——适合隐蔽噪声源、设备故障与取证。",
    "zh-Hant": "【高靈敏度】捕捉空氣中的真實物理能量。夜間安靜房間可測到冷氣、冰箱壓縮機、管線轟鳴等不易察覺的聲音。讀數通常更高——適合隱蔽噪音源、設備故障與取證。",
    "es": "[Alta sensibilidad] Captura la energía física real en el aire. De noche puede detectar aires acondicionados, compresores y tuberías que no notas. Las lecturas suelen ser más altas—ideal para fuentes ocultas, fallos y pruebas.",
    "pt": "[Alta sensibilidade] Captura a energia física real no ar. À noite pode pegar AC, compressores e tubulações que você não percebe. Leituras costumam ser maiores—ideal para fontes ocultas, falhas e provas.",
    "ar": "[حساسية عالية] يلتقط الطاقة الفيزيائية الحقيقية في الهواء. ليلًا قد يلتقط التكييف والضواغط وأنابيب قد لا تلاحظها. القراءات أعلى عادة—مثالي للمصادر الخفية والأعطال والأدلة.",
    "fr": "[Haute sensibilité] Capture l’énergie physique réelle dans l’air. La nuit, détecte climatisation, compresseurs, tuyaux inaudibles. Mesures souvent plus hautes—idéal pour sources cachées, pannes et preuves.",
    "hi": "[उच्च संवेदनशीलता] हवा में वास्तविक भौतिक ऊर्जा पकड़ता है। रात में AC, कंप्रेसर, पाइप की गड़गड़ाहट जो सुनाई न दे। रीडिंग अक्सर अधिक—छिपे स्रोत, खराबी, साक्ष्य के लिए।",
    "ru": "[Высокая чувствительность] Захватывает реальную физическую энергию в воздухе. Ночью слышит кондиционеры, компрессоры, трубы. Показания обычно выше—для скрытых источников, неисправностей и доказательств."
  },
  "mode.highSensitivity.tooltipHeadline": {
    "en": "[High Sensitivity]",
    "zh-Hans": "【高灵敏度】",
    "zh-Hant": "【高靈敏度】",
    "es": "[Alta sensibilidad]",
    "pt": "[Alta sensibilidade]",
    "ar": "[حساسية عالية]",
    "fr": "[Haute sensibilité]",
    "hi": "[उच्च संवेदनशीलता]",
    "ru": "[Высокая чувствительность]"
  },
  "mode.highSensitivity.comparisonHint": {
    "en": "Readings are often higher than standard mode—that is normal; it measures sound you may not hear but is still there.",
    "zh-Hans": "读数常高于标准模式——属正常；它测量您可能听不见但仍存在的声音。",
    "zh-Hant": "讀數常高於標準模式——屬正常；它測量您可能聽不見但仍存在的聲音。",
    "es": "Las lecturas suelen ser más altas que en modo estándar—es normal; mide sonido que quizá no oyes pero está ahí.",
    "pt": "As leituras costumam ser maiores que no modo padrão—é normal; mede som que você talvez não ouça, mas está lá.",
    "ar": "القراءات غالبًا أعلى من الوضع القياسي—هذا طبيعي؛ يقيس صوتًا قد لا تسمعه لكنه موجود.",
    "fr": "Les mesures sont souvent plus hautes qu’en standard—c’est normal ; elles mesurent du son inaudible mais présent.",
    "hi": "रीडिंग अक्सर मानक से अधिक—यह सामान्य है; ऐसी ध्वनि मापता है जो सुनाई न दे पर मौजूद हो।",
    "ru": "Показания часто выше стандартного режима—это нормально; измеряется звук, который вы можете не слышать."
  },
  "weighting.a.displayName": {
    "en": "A-weighting (dBA)",
    "zh-Hans": "A 计权 (dBA)",
    "zh-Hant": "A 計權 (dBA)",
    "es": "Ponderación A (dBA)",
    "pt": "Ponderação A (dBA)",
    "ar": "ترجيح A (dBA)",
    "fr": "Pondération A (dBA)",
    "hi": "A-भारण (dBA)",
    "ru": "A-взвешивание (dBA)"
  },
  "weighting.c.displayName": {
    "en": "C-weighting (dBC)",
    "zh-Hans": "C 计权 (dBC)",
    "zh-Hant": "C 計權 (dBC)",
    "es": "Ponderación C (dBC)",
    "pt": "Ponderação C (dBC)",
    "ar": "ترجيح C (dBC)",
    "fr": "Pondération C (dBC)",
    "hi": "C-भारण (dBC)",
    "ru": "C-взвешивание (dBC)"
  },
  "weighting.z.displayName": {
    "en": "Z-weighting (dBZ)",
    "zh-Hans": "Z 计权 (dBZ)",
    "zh-Hant": "Z 計權 (dBZ)",
    "es": "Ponderación Z (dBZ)",
    "pt": "Ponderação Z (dBZ)",
    "ar": "ترجيح Z (dBZ)",
    "fr": "Pondération Z (dBZ)",
    "hi": "Z-भारण (dBZ)",
    "ru": "Z-взвешивание (dBZ)"
  },
  "silenceGrade.a.title": {
    "en": "Grade A — Excellent",
    "zh-Hans": "等级 A — 优秀",
    "zh-Hant": "等級 A — 優秀",
    "es": "Grado A — Excelente",
    "pt": "Nota A — Excelente",
    "ar": "الدرجة A — ممتاز",
    "fr": "Note A — Excellent",
    "hi": "ग्रेड A — उत्कृष्ट",
    "ru": "Класс A — Отлично"
  },
  "silenceGrade.a.description": {
    "en": "Very quiet environment suitable for rest and concentration.",
    "zh-Hans": "非常安静，适合休息与专注。",
    "zh-Hant": "非常安靜，適合休息與專注。",
    "es": "Entorno muy silencioso, adecuado para descanso y concentración.",
    "pt": "Ambiente muito silencioso, adequado para descanso e concentração.",
    "ar": "بيئة هادئة جدًا مناسبة للراحة والتركيز.",
    "fr": "Environnement très calme, propice au repos et à la concentration.",
    "hi": "बहुत शांत वातावरण, आराम और एकाग्रता के लिए उपयुक्त।",
    "ru": "Очень тихая среда, подходит для отдыха и концентрации."
  },
  "silenceGrade.b.title": {
    "en": "Grade B — Good",
    "zh-Hans": "等级 B — 良好",
    "zh-Hant": "等級 B — 良好",
    "es": "Grado B — Bueno",
    "pt": "Nota B — Bom",
    "ar": "الدرجة B — جيد",
    "fr": "Note B — Bon",
    "hi": "ग्रेड B — अच्छा",
    "ru": "Класс B — Хорошо"
  },
  "silenceGrade.b.description": {
    "en": "Generally quiet with occasional minor disturbances.",
    "zh-Hans": "总体安静，偶有轻微干扰。",
    "zh-Hant": "總體安靜，偶有輕微干擾。",
    "es": "En general silencioso con molestias menores ocasionales.",
    "pt": "Em geral silencioso com perturbações leves ocasionais.",
    "ar": "هادئ عمومًا مع إزعاج طفيف أحيانًا.",
    "fr": "Globalement calme avec de rares nuisances mineures.",
    "hi": "सामान्यतः शांत, कभी-कभी हल्की व्यवधान।",
    "ru": "В целом тихо, изредка незначительные помехи."
  },
  "silenceGrade.c.title": {
    "en": "Grade C — Fair",
    "zh-Hans": "等级 C — 一般",
    "zh-Hant": "等級 C — 一般",
    "es": "Grado C — Aceptable",
    "pt": "Nota C — Razoável",
    "ar": "الدرجة C — مقبول",
    "fr": "Note C — Passable",
    "hi": "ग्रेड C — ठीक",
    "ru": "Класс C — Удовлетворительно"
  },
  "silenceGrade.c.description": {
    "en": "Noticeable background noise; may affect sleep or work.",
    "zh-Hans": "背景噪声明显，可能影响睡眠或工作。",
    "zh-Hant": "背景噪音明顯，可能影響睡眠或工作。",
    "es": "Ruido de fondo notable; puede afectar el sueño o el trabajo.",
    "pt": "Ruído de fundo perceptível; pode afetar sono ou trabalho.",
    "ar": "ضوضاء خلفية ملحوظة؛ قد تؤثر على النوم أو العمل.",
    "fr": "Bruit de fond notable ; peut gêner le sommeil ou le travail.",
    "hi": "पृष्ठभूमि शोर स्पष्ट; नींद/काम प्रभावित हो सकता है।",
    "ru": "Заметный фоновый шум; может мешать сну или работе."
  },
  "silenceGrade.d.title": {
    "en": "Grade D — Poor",
    "zh-Hans": "等级 D — 较差",
    "zh-Hant": "等級 D — 較差",
    "es": "Grado D — Deficiente",
    "pt": "Nota D — Ruim",
    "ar": "الدرجة D — ضعيف",
    "fr": "Note D — Médiocre",
    "hi": "ग्रेड D — खराब",
    "ru": "Класс D — Плохо"
  },
  "silenceGrade.d.description": {
    "en": "Loud or persistent noise; corrective action recommended.",
    "zh-Hans": "噪声较大或持续，建议采取改善措施。",
    "zh-Hant": "噪音較大或持續，建議採取改善措施。",
    "es": "Ruido alto o persistente; se recomienda actuar.",
    "pt": "Ruído alto ou persistente; recomenda-se ação corretiva.",
    "ar": "ضوضاء عالية أو مستمرة؛ يُنصح باتخاذ إجراء.",
    "fr": "Bruit fort ou persistant ; action corrective recommandée.",
    "hi": "तेज़ या लगातार शोर; सुधार की सिफ़ारिश।",
    "ru": "Громкий или постоянный шум; рекомендуется устранить причину."
  },
  "noiseRisk.quiet": {
    "en": "Quiet",
    "zh-Hans": "安静",
    "zh-Hant": "安靜",
    "es": "Silencioso",
    "pt": "Silencioso",
    "ar": "هادئ",
    "fr": "Calme",
    "hi": "शांत",
    "ru": "Тихо"
  },
  "noiseRisk.moderate": {
    "en": "Moderate",
    "zh-Hans": "适中",
    "zh-Hant": "適中",
    "es": "Moderado",
    "pt": "Moderado",
    "ar": "معتدل",
    "fr": "Modéré",
    "hi": "मध्यम",
    "ru": "Умеренно"
  },
  "noiseRisk.loud": {
    "en": "Loud",
    "zh-Hans": "响亮",
    "zh-Hant": "響亮",
    "es": "Alto",
    "pt": "Alto",
    "ar": "عالٍ",
    "fr": "Fort",
    "hi": "तेज़",
    "ru": "Громко"
  },
  "noiseRisk.dangerous": {
    "en": "Dangerous",
    "zh-Hans": "危险",
    "zh-Hant": "危險",
    "es": "Peligroso",
    "pt": "Perigoso",
    "ar": "خطير",
    "fr": "Dangereux",
    "hi": "खतरनाक",
    "ru": "Опасно"
  },
  "gauge.highSensitivity.hint": {
    "en": "High-sensitivity readings are often higher than you perceive.",
    "zh-Hans": "高灵敏度读数通常高于主观感受。",
    "zh-Hant": "高靈敏度讀數通常高於主觀感受。",
    "es": "Las lecturas de alta sensibilidad suelen ser más altas de lo que percibes.",
    "pt": "Leituras de alta sensibilidade costumam ser maiores do que você percebe.",
    "ar": "قراءات الحساسية العالية غالبًا أعلى مما تدركه.",
    "fr": "Les mesures haute sensibilité sont souvent plus hautes que perçu.",
    "hi": "उच्च-संवेदनशीलता रीडिंग अक्सर अनुभव से अधिक होती हैं।",
    "ru": "Показания высокой чувствительности часто выше субъективного восприятия."
  },
  "spectrum.loading": {
    "en": "Loading spectrum…",
    "zh-Hans": "正在加载频谱…",
    "zh-Hant": "正在載入頻譜…",
    "es": "Cargando espectro…",
    "pt": "Carregando espectro…",
    "ar": "جارٍ تحميل الطيف…",
    "fr": "Chargement du spectre…",
    "hi": "स्पेक्ट्रम लोड हो रहा है…",
    "ru": "Загрузка спектра…"
  },
  "overlay.decibel.prefix": {
    "en": "Noise",
    "zh-Hans": "噪声",
    "zh-Hant": "噪音",
    "es": "Ruido",
    "pt": "Ruído",
    "ar": "ضوضاء",
    "fr": "Bruit",
    "hi": "शोर",
    "ru": "Шум"
  },
  "overlay.gps.unavailable": {
    "en": "GPS unavailable",
    "zh-Hans": "GPS 不可用",
    "zh-Hant": "GPS 不可用",
    "es": "GPS no disponible",
    "pt": "GPS indisponível",
    "ar": "GPS غير متاح",
    "fr": "GPS indisponible",
    "hi": "GPS उपलब्ध नहीं",
    "ru": "GPS недоступен"
  },
  "overlay.gps.coordinates": {
    "en": "Lat: %.4f, Lon: %.4f",
    "zh-Hans": "纬度：%.4f，经度：%.4f",
    "zh-Hant": "緯度：%.4f，經度：%.4f",
    "es": "Lat: %.4f, Lon: %.4f",
    "pt": "Lat: %.4f, Lon: %.4f",
    "ar": "خط العرض: %.4f، خط الطول: %.4f",
    "fr": "Lat. : %.4f, Long. : %.4f",
    "hi": "अक्षांश: %.4f, देशांतर: %.4f",
    "ru": "Шир.: %.4f, долг.: %.4f"
  },
  "overlay.decibel.default": {
    "en": "0.0 dBA",
    "zh-Hans": "0.0 dBA",
    "zh-Hant": "0.0 dBA",
    "es": "0.0 dBA",
    "pt": "0.0 dBA",
    "ar": "0.0 dBA",
    "fr": "0.0 dBA",
    "hi": "0.0 dBA",
    "ru": "0.0 dBA"
  },
  "silenceReport.generated": {
    "en": "Generated",
    "zh-Hans": "生成时间",
    "zh-Hant": "產生時間",
    "es": "Generado",
    "pt": "Gerado",
    "ar": "تاريخ الإنشاء",
    "fr": "Généré",
    "hi": "जनरेट किया गया",
    "ru": "Создано"
  },
  "silenceReport.device": {
    "en": "Device",
    "zh-Hans": "设备",
    "zh-Hant": "裝置",
    "es": "Dispositivo",
    "pt": "Dispositivo",
    "ar": "الجهاز",
    "fr": "Appareil",
    "hi": "डिवाइस",
    "ru": "Устройство"
  },
  "silenceReport.weighting": {
    "en": "Weighting",
    "zh-Hans": "计权",
    "zh-Hant": "計權",
    "es": "Ponderación",
    "pt": "Ponderação",
    "ar": "الترجيح",
    "fr": "Pondération",
    "hi": "भारण",
    "ru": "Взвешивание"
  },
  "silenceReport.grade": {
    "en": "Silence grade",
    "zh-Hans": "静音等级",
    "zh-Hant": "靜音等級",
    "es": "Grado de silencio",
    "pt": "Nota de silêncio",
    "ar": "درجة الصمت",
    "fr": "Note de silence",
    "hi": "मौन ग्रेड",
    "ru": "Класс тишины"
  },
  "silenceReport.gradeLine": {
    "en": "%1$@ — %2$@",
    "zh-Hans": "%1$@ — %2$@",
    "zh-Hant": "%1$@ — %2$@",
    "es": "%1$@ — %2$@",
    "pt": "%1$@ — %2$@",
    "ar": "%1$@ — %2$@",
    "fr": "%1$@ — %2$@",
    "hi": "%1$@ — %2$@",
    "ru": "%1$@ — %2$@"
  },
  "silenceReport.leq": {
    "en": "Leq",
    "zh-Hans": "Leq",
    "zh-Hant": "Leq",
    "es": "Leq",
    "pt": "Leq",
    "ar": "Leq",
    "fr": "Leq",
    "hi": "Leq",
    "ru": "Leq"
  },
  "silenceReport.max": {
    "en": "Max",
    "zh-Hans": "最大",
    "zh-Hant": "最大",
    "es": "Máx.",
    "pt": "Máx.",
    "ar": "الحد الأقصى",
    "fr": "Max.",
    "hi": "अधिकतम",
    "ru": "Макс."
  },
  "silenceReport.min": {
    "en": "Min",
    "zh-Hans": "最小",
    "zh-Hant": "最小",
    "es": "Mín.",
    "pt": "Mín.",
    "ar": "الحد الأدنى",
    "fr": "Min.",
    "hi": "न्यूनतम",
    "ru": "Мин."
  },
  "silenceReport.avg": {
    "en": "Average",
    "zh-Hans": "平均",
    "zh-Hant": "平均",
    "es": "Promedio",
    "pt": "Média",
    "ar": "المتوسط",
    "fr": "Moyenne",
    "hi": "औसत",
    "ru": "Среднее"
  },
  "silenceReport.disclaimer": {
    "en": "This report is for informational purposes only and is not a certified legal or environmental measurement.",
    "zh-Hans": "本报告仅供参考，不构成具有法律或环境认证效力的测量结果。",
    "zh-Hant": "本報告僅供參考，不構成具有法律或環境認證效力的測量結果。",
    "es": "Este informe es solo informativo y no constituye una medición certificada legal o ambiental.",
    "pt": "Este relatório é apenas informativo e não é uma medição legal ou ambiental certificada.",
    "ar": "هذا التقرير لأغراض معلوماتية فقط وليس قياسًا قانونيًا أو بيئيًا معتمدًا.",
    "fr": "Ce rapport est informatif uniquement et ne constitue pas une mesure certifiée légale ou environnementale.",
    "hi": "यह रिपोर्ट केवल जानकारी के लिए है; प्रमाणित कानूनी/पर्यावरण माप नहीं।",
    "ru": "Отчёт носит информационный характер и не является сертифицированным юридическим или экологическим измерением."
  },
  "aiLabel.speech": {
    "en": "Speech",
    "zh-Hans": "语音",
    "zh-Hant": "語音",
    "es": "Voz",
    "pt": "Fala",
    "ar": "كلام",
    "fr": "Parole",
    "hi": "बोली",
    "ru": "Речь"
  },
  "aiLabel.music": {
    "en": "Music",
    "zh-Hans": "音乐",
    "zh-Hant": "音樂",
    "es": "Música",
    "pt": "Música",
    "ar": "موسيقى",
    "fr": "Musique",
    "hi": "संगीत",
    "ru": "Музыка"
  },
  "aiLabel.dog": {
    "en": "Dog",
    "zh-Hans": "狗",
    "zh-Hant": "狗",
    "es": "Perro",
    "pt": "Cachorro",
    "ar": "كلب",
    "fr": "Chien",
    "hi": "कुत्ता",
    "ru": "Собака"
  },
  "aiLabel.cat": {
    "en": "Cat",
    "zh-Hans": "猫",
    "zh-Hant": "貓",
    "es": "Gato",
    "pt": "Gato",
    "ar": "قطة",
    "fr": "Chat",
    "hi": "बिल्ली",
    "ru": "Кошка"
  },
  "aiLabel.car": {
    "en": "Car",
    "zh-Hans": "汽车",
    "zh-Hant": "汽車",
    "es": "Coche",
    "pt": "Carro",
    "ar": "سيارة",
    "fr": "Voiture",
    "hi": "कार",
    "ru": "Автомобиль"
  },
  "aiLabel.engine": {
    "en": "Engine",
    "zh-Hans": "发动机",
    "zh-Hant": "引擎",
    "es": "Motor",
    "pt": "Motor",
    "ar": "محرك",
    "fr": "Moteur",
    "hi": "इंजन",
    "ru": "Двигатель"
  },
  "aiLabel.drill": {
    "en": "Drill",
    "zh-Hans": "电钻",
    "zh-Hant": "電鑽",
    "es": "Taladro",
    "pt": "Furadeira",
    "ar": "مثقاب",
    "fr": "Perceuse",
    "hi": "ड्रिल",
    "ru": "Дрель"
  },
  "aiLabel.hammer": {
    "en": "Hammer",
    "zh-Hans": "锤子",
    "zh-Hant": "錘子",
    "es": "Martillo",
    "pt": "Martelo",
    "ar": "مطرقة",
    "fr": "Marteau",
    "hi": "हथौड़ा",
    "ru": "Молоток"
  },
  "aiLabel.alarm": {
    "en": "Alarm",
    "zh-Hans": "警报",
    "zh-Hant": "警報",
    "es": "Alarma",
    "pt": "Alarme",
    "ar": "إنذار",
    "fr": "Alarme",
    "hi": "अलार्म",
    "ru": "Сигнал"
  },
  "aiLabel.siren": {
    "en": "Siren",
    "zh-Hans": "警笛",
    "zh-Hant": "警笛",
    "es": "Sirena",
    "pt": "Sirene",
    "ar": "صفارة",
    "fr": "Sirène",
    "hi": "सायरन",
    "ru": "Сирена"
  },
  "aiLabel.applause": {
    "en": "Applause",
    "zh-Hans": "掌声",
    "zh-Hant": "掌聲",
    "es": "Aplausos",
    "pt": "Aplausos",
    "ar": "تصفيق",
    "fr": "Applaudissements",
    "hi": "तालियाँ",
    "ru": "Аплодисменты"
  },
  "aiLabel.laughter": {
    "en": "Laughter",
    "zh-Hans": "笑声",
    "zh-Hant": "笑聲",
    "es": "Risas",
    "pt": "Risadas",
    "ar": "ضحك",
    "fr": "Rires",
    "hi": "हँसी",
    "ru": "Смех"
  },
  "error.audio.permissionDenied": {
    "en": "Microphone access was denied. Enable it in Settings to measure noise.",
    "zh-Hans": "麦克风权限被拒绝。请在设置中开启以测量噪声。",
    "zh-Hant": "麥克風權限遭拒。請在設定中開啟以測量噪音。",
    "es": "Se denegó el acceso al micrófono. Actívalo en Ajustes para medir el ruido.",
    "pt": "O acesso ao microfone foi negado. Ative em Ajustes para medir o ruído.",
    "ar": "تم رفض الوصول إلى الميكروفون. فعّله في الإعدادات لقياس الضوضاء.",
    "fr": "L’accès au micro a été refusé. Activez-le dans Réglages pour mesurer le bruit.",
    "hi": "माइक्रोफ़ोन एक्सेस अस्वीकृत। शोर मापने के लिए सेटिंग्स में चालू करें।",
    "ru": "Доступ к микрофону запрещён. Включите в «Настройках» для измерения шума."
  },
  "error.audio.activationFailed": {
    "en": "Could not activate the audio session.",
    "zh-Hans": "无法激活音频会话。",
    "zh-Hant": "無法啟用音訊工作階段。",
    "es": "No se pudo activar la sesión de audio.",
    "pt": "Não foi possível ativar a sessão de áudio.",
    "ar": "تعذر تفعيل جلسة الصوت.",
    "fr": "Impossible d’activer la session audio.",
    "hi": "ऑडियो सत्र सक्रिय नहीं हो सका।",
    "ru": "Не удалось активировать аудиосессию."
  },
  "error.audio.configurationFailed": {
    "en": "Audio configuration failed: %1$@",
    "zh-Hans": "音频配置失败：%1$@",
    "zh-Hant": "音訊設定失敗：%1$@",
    "es": "Error de configuración de audio: %1$@",
    "pt": "Falha na configuração de áudio: %1$@",
    "ar": "فشل إعداد الصوت: %1$@",
    "fr": "Échec de la configuration audio : %1$@",
    "hi": "ऑडियो कॉन्फ़िगरेशन विफल: %1$@",
    "ru": "Ошибка настройки аудио: %1$@"
  },
  "error.engine.startFailed": {
    "en": "Could not start the audio engine: %1$@",
    "zh-Hans": "无法启动音频引擎：%1$@",
    "zh-Hant": "無法啟動音訊引擎：%1$@",
    "es": "No se pudo iniciar el motor de audio: %1$@",
    "pt": "Não foi possível iniciar o mecanismo de áudio: %1$@",
    "ar": "تعذر بدء محرك الصوت: %1$@",
    "fr": "Impossible de démarrer le moteur audio : %1$@",
    "hi": "ऑडियो इंजन शुरू नहीं हो सका: %1$@",
    "ru": "Не удалось запустить аудиодвижок: %1$@"
  },
  "error.playback.prepareFailed": {
    "en": "Could not prepare playback.",
    "zh-Hans": "无法准备播放。",
    "zh-Hant": "無法準備播放。",
    "es": "No se pudo preparar la reproducción.",
    "pt": "Não foi possível preparar a reprodução.",
    "ar": "تعذر تجهيز التشغيل.",
    "fr": "Impossible de préparer la lecture.",
    "hi": "प्लेबैक तैयार नहीं हो सका।",
    "ru": "Не удалось подготовить воспроизведение."
  },
  "error.playback.startFailed": {
    "en": "Could not start playback.",
    "zh-Hans": "无法开始播放。",
    "zh-Hant": "無法開始播放。",
    "es": "No se pudo iniciar la reproducción.",
    "pt": "Não foi possível iniciar a reprodução.",
    "ar": "تعذر بدء التشغيل.",
    "fr": "Impossible de démarrer la lecture.",
    "hi": "प्लेबैक शुरू नहीं हो सका।",
    "ru": "Не удалось начать воспроизведение."
  },
  "error.video.cameraUnavailable": {
    "en": "Camera is not available on this device.",
    "zh-Hans": "此设备无法使用相机。",
    "zh-Hant": "此裝置無法使用相機。",
    "es": "La cámara no está disponible en este dispositivo.",
    "pt": "A câmera não está disponível neste dispositivo.",
    "ar": "الكاميرا غير متاحة على هذا الجهاز.",
    "fr": "La caméra n’est pas disponible sur cet appareil.",
    "hi": "इस डिवाइस पर कैमरा उपलब्ध नहीं।",
    "ru": "Камера недоступна на этом устройстве."
  },
  "error.video.microphoneUnavailable": {
    "en": "Microphone is not available for video recording.",
    "zh-Hans": "视频录制无法使用麦克风。",
    "zh-Hant": "影片錄製無法使用麥克風。",
    "es": "El micrófono no está disponible para grabar vídeo.",
    "pt": "O microfone não está disponível para gravar vídeo.",
    "ar": "الميكروفون غير متاح لتسجيل الفيديو.",
    "fr": "Le micro n’est pas disponible pour l’enregistrement vidéo.",
    "hi": "वीडियो रिकॉर्डिंग के लिए माइक्रोफ़ोन उपलब्ध नहीं।",
    "ru": "Микрофон недоступен для записи видео."
  },
  "error.video.notRecording": {
    "en": "Video is not recording.",
    "zh-Hans": "视频未在录制。",
    "zh-Hant": "影片未在錄製。",
    "es": "El vídeo no se está grabando.",
    "pt": "O vídeo não está gravando.",
    "ar": "الفيديو لا يُسجَّل.",
    "fr": "La vidéo n’enregistre pas.",
    "hi": "वीडियो रिकॉर्ड नहीं हो रहा।",
    "ru": "Видео не записывается."
  },
  "error.video.writerAddTrackFailed": {
    "en": "Could not add a track to the video file.",
    "zh-Hans": "无法向视频文件添加轨道。",
    "zh-Hant": "無法向影片檔案新增軌道。",
    "es": "No se pudo añadir una pista al archivo de vídeo.",
    "pt": "Não foi possível adicionar uma faixa ao arquivo de vídeo.",
    "ar": "تعذت إضافة مسار إلى ملف الفيديو.",
    "fr": "Impossible d’ajouter une piste au fichier vidéo.",
    "hi": "वीडियो फ़ाइल में ट्रैक नहीं जोड़ा जा सका।",
    "ru": "Не удалось добавить дорожку в видеофайл."
  },
  "error.video.writerSetupFailed": {
    "en": "Video writer setup failed: %1$@",
    "zh-Hans": "视频写入器设置失败：%1$@",
    "zh-Hant": "影片寫入器設定失敗：%1$@",
    "es": "Error al configurar el escritor de vídeo: %1$@",
    "pt": "Falha na configuração do gravador de vídeo: %1$@",
    "ar": "فشل إعداد كاتب الفيديو: %1$@",
    "fr": "Échec de la configuration de l’encodeur vidéo : %1$@",
    "hi": "वीडियो राइटर सेटअप विफल: %1$@",
    "ru": "Ошибка настройки видеозаписи: %1$@"
  },
  "error.video.finishFailed": {
    "en": "Could not finish saving the video: %1$@",
    "zh-Hans": "无法完成保存视频：%1$@",
    "zh-Hant": "無法完成儲存影片：%1$@",
    "es": "No se pudo terminar de guardar el vídeo: %1$@",
    "pt": "Não foi possível concluir o salvamento do vídeo: %1$@",
    "ar": "تعذر إنهاء حفظ الفيديو: %1$@",
    "fr": "Impossible de terminer l’enregistrement de la vidéo : %1$@",
    "hi": "वीडियो सहेजना पूरा नहीं हो सका: %1$@",
    "ru": "Не удалось завершить сохранение видео: %1$@"
  },
  "error.unknown": {
    "en": "An unknown error occurred.",
    "zh-Hans": "发生未知错误。",
    "zh-Hant": "發生未知錯誤。",
    "es": "Ocurrió un error desconocido.",
    "pt": "Ocorreu um erro desconhecido.",
    "ar": "حدث خطأ غير معروف.",
    "fr": "Une erreur inconnue s’est produite.",
    "hi": "अज्ञात त्रुटि हुई।",
    "ru": "Произошла неизвестная ошибка."
  },
  "NSCameraUsageDescription": {
    "en": "Camera access is required to record evidence video with decibel overlays.",
    "zh-Hans": "需要相机权限以录制带分贝叠加的取证视频。",
    "zh-Hant": "需要相機權限以錄製帶分貝疊加的取證影片。",
    "es": "Se necesita la cámara para grabar vídeo de prueba con superposición de decibelios.",
    "pt": "É necessário acesso à câmera para gravar vídeo de prova com sobreposição de decibéis.",
    "ar": "يلزم الوصول إلى الكاميرا لتسجيل فيديو دليل مع تراكب الديسيبل.",
    "fr": "L’accès à la caméra est requis pour enregistrer une preuve vidéo avec mesures en décibels.",
    "hi": "डेसिबल ओवरले के साथ साक्ष्य वीडियो के लिए कैमरा एक्सेस आवश्यक है।",
    "ru": "Нужен доступ к камере для записи видеодоказательств с наложением децибел."
  },
  "NSMicrophoneUsageDescription": {
    "en": "Microphone access is required to measure noise and record voice-activated audio.",
    "zh-Hans": "需要麦克风权限以测量噪声并进行声控录音。",
    "zh-Hant": "需要麥克風權限以測量噪音並進行聲控錄音。",
    "es": "Se necesita el micrófono para medir el ruido y grabar audio activado por voz.",
    "pt": "É necessário acesso ao microfone para medir ruído e gravar áudio por voz.",
    "ar": "يلزم الوصول إلى الميكروفون لقياس الضوضاء وتسجيل الصوت بالتفعيل الصوتي.",
    "fr": "L’accès au micro est requis pour mesurer le bruit et enregistrer l’audio vocal.",
    "hi": "शोर मापने और वॉइस-सक्रिय ऑडियो के लिए माइक्रोफ़ोन एक्सेस आवश्यक है।",
    "ru": "Нужен доступ к микрофону для измерения шума и голосовой записи."
  },
  "NSLocationWhenInUseUsageDescription": {
    "en": "Location is used to embed GPS coordinates in evidence video.",
    "zh-Hans": "使用位置信息将 GPS 坐标嵌入取证视频。",
    "zh-Hant": "使用位置資訊將 GPS 座標嵌入取證影片。",
    "es": "La ubicación se usa para incrustar coordenadas GPS en el vídeo de prueba.",
    "pt": "A localização é usada para incorporar coordenadas GPS no vídeo de prova.",
    "ar": "يُستخدم الموقع لتضمين إحداثيات GPS في فيديو الدليل.",
    "fr": "La position sert à intégrer les coordonnées GPS dans la preuve vidéo.",
    "hi": "साक्ष्य वीडियो में GPS निर्देशांक जोड़ने के लिए स्थान का उपयोग होता है।",
    "ru": "Геопозиция используется для встраивания GPS-координат в видеодоказательство."
  },
  "NSUserTrackingUsageDescription": {
    "en": "This identifier is used to deliver personalized ads and measure ad performance.",
    "zh-Hans": "此标识符用于投放个性化广告并衡量广告效果。",
    "zh-Hant": "此識別碼用於投放個人化廣告並衡量廣告成效。",
    "es": "Este identificador se usa para mostrar anuncios personalizados y medir su rendimiento.",
    "pt": "Este identificador é usado para exibir anúncios personalizados e medir o desempenho dos anúncios.",
    "ar": "يُستخدم هذا المعرّف لتقديم إعلانات مخصصة وقياس أداء الإعلانات.",
    "fr": "Cet identifiant sert à diffuser des publicités personnalisées et à mesurer leurs performances.",
    "hi": "यह पहचानकर्ता व्यक्तिगत विज्ञापन देने और विज्ञापन प्रदर्शन मापने के लिए उपयोग होता है।",
    "ru": "Этот идентификатор используется для показа персонализированной рекламы и оценки её эффективности."
  },
  "settings.privacyChoices": {
    "en": "Ad Privacy Choices",
    "zh-Hans": "广告隐私选项",
    "zh-Hant": "廣告隱私選項",
    "es": "Opciones de privacidad de anuncios",
    "pt": "Opções de privacidade de anúncios",
    "ar": "خيارات خصوصية الإعلانات",
    "fr": "Choix de confidentialité des annonces",
    "hi": "विज्ञापन गोपनीयता विकल्प",
    "ru": "Настройки конфиденциальности рекламы"
  }
}"""


def collect_localizable_keys() -> list[str]:
    keys = set(parse_l10n_keys(L10N_SWIFT))
    keys.update(EXTRA_LOCALIZABLE_KEYS)
    return sorted(keys)


def build_xcstrings(keys: list[str], catalog: dict[str, dict[str, str]]) -> dict:
    strings: dict = {}
    missing: list[str] = []
    for key in keys:
        entry = catalog.get(key)
        if not entry:
            missing.append(key)
            continue
        localizations: dict = {}
        for locale in LOCALES:
            value = entry.get(locale)
            if value is None:
                missing.append(f"{key}@{locale}")
                continue
            localizations[locale] = {
                "stringUnit": {
                    "state": "translated",
                    "value": value,
                }
            }
        strings[key] = {
            "extractionState": "manual",
            "localizations": localizations,
        }
    if missing:
        unique = sorted(set(missing))
        raise SystemExit(
            "Missing catalog entries:\\n" + "\\n".join(unique[:50])
            + (f"\\n... and {len(unique) - 50} more" if len(unique) > 50 else "")
        )
    return {
        "sourceLanguage": SOURCE_LANGUAGE,
        "strings": strings,
        "version": "1.0",
    }


def build_infoplist_xcstrings(catalog: dict[str, dict[str, str]]) -> dict:
    return build_xcstrings(INFOPLIST_KEYS, catalog)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    catalog = load_catalog()
    localizable_keys = collect_localizable_keys()
    localizable = build_xcstrings(localizable_keys, catalog)
    infoplist = build_infoplist_xcstrings(catalog)
    write_json(OUT_LOCALIZABLE, localizable)
    write_json(OUT_INFOPLIST, infoplist)
    print(f"Localizable keys: {len(localizable_keys)}")
    print(f"InfoPlist keys: {len(INFOPLIST_KEYS)}")
    print(f"Wrote {OUT_LOCALIZABLE}")
    print(f"Wrote {OUT_INFOPLIST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

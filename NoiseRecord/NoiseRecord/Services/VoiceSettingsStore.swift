import Foundation

/// Persisted Voice tab settings (thresholds, toggles, AI filter labels).
nonisolated enum VoiceSettingsStore {
    private static let highThresholdKey = "settings.highThreshold"
    private static let lowThresholdKey = "settings.lowThreshold"
    private static let voiceActivatedKey = "settings.voiceActivated"
    private static let backgroundMonitoringKey = "settings.backgroundMonitoring"
    private static let aiClassificationKey = "settings.aiClassification"
    private static let aiFilterLabelsKey = "settings.aiFilterLabels"

    static let defaultHighThreshold: Float = 55
    static let defaultLowThreshold: Float = 48

    static var highThreshold: Float {
        get { float(forKey: highThresholdKey, default: defaultHighThreshold) }
        set { UserDefaults.standard.set(newValue, forKey: highThresholdKey) }
    }

    static var lowThreshold: Float {
        get { float(forKey: lowThresholdKey, default: defaultLowThreshold) }
        set { UserDefaults.standard.set(newValue, forKey: lowThresholdKey) }
    }

    static var voiceActivatedEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: voiceActivatedKey) }
        set { UserDefaults.standard.set(newValue, forKey: voiceActivatedKey) }
    }

    static var backgroundMonitoringEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: backgroundMonitoringKey) }
        set { UserDefaults.standard.set(newValue, forKey: backgroundMonitoringKey) }
    }

    static var aiClassificationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: aiClassificationKey) }
        set { UserDefaults.standard.set(newValue, forKey: aiClassificationKey) }
    }

    static var aiFilterLabels: Set<String> {
        get {
            guard let labels = UserDefaults.standard.array(forKey: aiFilterLabelsKey) as? [String] else {
                return []
            }
            return Set(labels)
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: aiFilterLabelsKey)
        }
    }

    static func persist(
        highThreshold: Float,
        lowThreshold: Float,
        voiceActivatedEnabled: Bool,
        backgroundMonitoringEnabled: Bool,
        aiClassificationEnabled: Bool,
        aiFilterLabels: Set<String>
    ) {
        self.highThreshold = highThreshold
        self.lowThreshold = lowThreshold
        self.voiceActivatedEnabled = voiceActivatedEnabled
        self.backgroundMonitoringEnabled = backgroundMonitoringEnabled
        self.aiClassificationEnabled = aiClassificationEnabled
        self.aiFilterLabels = aiFilterLabels
    }

    private static func float(forKey key: String, default defaultValue: Float) -> Float {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.float(forKey: key)
    }
}

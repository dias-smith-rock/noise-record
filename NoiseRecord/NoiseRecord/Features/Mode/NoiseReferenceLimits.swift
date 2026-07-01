import Foundation

/// Waveform / report reference limits (informational only; not certified legal measurement).
enum NoiseReferenceLimits {
    static let didChangeNotification = Notification.Name("NoiseReferenceLimits.didChange")

    /// Default US residential night reference used on first launch.
    static let defaultResidentialNightDB: Float = 55

    /// Legacy alias for the configurable residential night reference.
    static var usResidentialNightDB: Float { residentialNightDB }

    static let configurableMinDB: Float = 35
    static let configurableMaxDB: Float = 75

    private static let residentialNightKey = "settings.waveformResidentialNightReferenceDB"

    /// User-configurable residential night reference (dBA).
    static var residentialNightDB: Float {
        get {
            guard UserDefaults.standard.object(forKey: residentialNightKey) != nil else {
                return defaultResidentialNightDB
            }
            let stored = UserDefaults.standard.float(forKey: residentialNightKey)
            return clamp(stored.rounded())
        }
        set {
            UserDefaults.standard.set(clamp(newValue.rounded()), forKey: residentialNightKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func shouldShowReferenceLine(
        mode: AcousticMeasurementMode,
        showsReferenceLimitLine: Bool,
        referenceDB: Float = residentialNightDB
    ) -> Bool {
        guard showsReferenceLimitLine else { return false }
        return isWithinWaveformRange(db: referenceDB, mode: mode)
    }

    static func isWithinWaveformRange(db: Float, mode: AcousticMeasurementMode) -> Bool {
        db >= mode.waveformMinDB && db <= mode.waveformMaxDB
    }

    static func resetResidentialNightReference() {
        residentialNightDB = defaultResidentialNightDB
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, configurableMinDB), configurableMaxDB)
    }
}

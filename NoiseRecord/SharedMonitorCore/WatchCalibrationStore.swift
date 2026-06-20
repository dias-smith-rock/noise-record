import Foundation

struct WatchCalibrationStore: Sendable {
    static let appGroupID = "group.com.goodcraft.NoiseRecord"
    private static let userAdjustmentKey = "watch.calibration.userAdjustment"
    private static let highSensitivityKey = "watch.settings.highSensitivityMode"

    static let defaultOffset: Float = 115.0

    private static let deviceLookup: [String: Float] = [
        "Watch7,1": 116.0,
        "Watch7,2": 116.0,
        "Watch7,3": 116.5,
        "Watch7,4": 116.5,
        "Watch7,5": 117.0,
        "Watch7,8": 117.0,
        "Watch7,9": 117.0,
        "Watch7,10": 117.0,
        "Watch6,1": 115.5,
        "Watch6,2": 115.5,
        "Watch6,3": 116.0,
        "Watch6,4": 116.0,
        "Watch6,6": 116.5,
        "Watch6,7": 116.5,
        "Watch6,8": 116.5,
        "Watch6,9": 116.5,
        "Watch6,10": 117.0,
        "Watch6,11": 117.0,
        "Watch6,12": 117.0,
        "Watch6,13": 117.0,
        "Watch6,14": 117.0,
        "Watch6,15": 117.0,
        "Watch6,16": 117.0,
        "Watch6,17": 117.0,
        "Watch6,18": 117.0,
    ]

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var deviceModelIdentifier: String {
        HardwareIdentifier.machineIdentifier
    }

    static var deviceOffset: Float {
        if let mapped = deviceLookup[deviceModelIdentifier] {
            return mapped
        }
        let model = deviceModelIdentifier
        if model.hasPrefix("Watch7") {
            return 117.0
        }
        if model.hasPrefix("Watch6") {
            return 116.5
        }
        return defaultOffset
    }

    static var userAdjustment: Float {
        get {
            guard defaults.object(forKey: userAdjustmentKey) != nil else { return 0 }
            return defaults.float(forKey: userAdjustmentKey)
        }
        set {
            defaults.set(newValue, forKey: userAdjustmentKey)
        }
    }

    static var totalOffset: Float {
        deviceOffset + userAdjustment
    }

    static var isHighSensitivityMode: Bool {
        get {
            guard defaults.object(forKey: highSensitivityKey) != nil else { return false }
            return defaults.bool(forKey: highSensitivityKey)
        }
        set {
            defaults.set(newValue, forKey: highSensitivityKey)
        }
    }

    static var weightingType: WeightingType {
        isHighSensitivityMode ? .z : .a
    }
}

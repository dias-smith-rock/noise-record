import Foundation
import UIKit

enum WeightingType: String, CaseIterable, Codable, Sendable {
    case a = "A"
    case c = "C"
    case z = "Z"

    var displayName: String {
        switch self {
        case .a: "dBA (A计权)"
        case .c: "dBC (C计权)"
        case .z: "dBZ (Z计权)"
        }
    }
}

struct DeviceCalibrationStore: Sendable {
    private static let userAdjustmentKey = "calibration.userAdjustment"
    private static let weightingKey = "settings.weighting"
    private static let highSensitivityKey = "settings.highSensitivityMode"

    /// Baseline offset for quiet-room display ~30–40 dBA in measurement mode.
    static let defaultOffset: Float = 115.0

    private static let deviceLookup: [String: Float] = [
        "iPhone17,1": 118.0,
        "iPhone17,2": 118.0,
        "iPhone17,3": 118.0,
        "iPhone17,4": 118.0,
        "iPhone16,1": 118.0,
        "iPhone16,2": 118.0,
        "iPhone15,4": 116.5,
        "iPhone15,5": 116.5,
        "iPhone15,2": 116.0,
        "iPhone15,3": 116.0,
        "iPhone14,7": 115.5,
        "iPhone14,8": 115.5,
        "iPhone14,2": 115.0,
        "iPhone14,3": 115.0,
        "iPhone13,2": 115.0,
        "iPhone13,3": 115.0,
        "iPad13,18": 115.0,
        "iPad13,19": 115.0,
    ]

    static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }

    /// Device hardware offset (115–118 dB range).
    static var deviceOffset: Float {
        if let mapped = deviceLookup[deviceModelIdentifier] {
            return mapped
        }
        let model = deviceModelIdentifier
        if model.hasPrefix("iPhone16") || model.hasPrefix("iPhone17") {
            return 118.0
        }
        return defaultOffset
    }

    /// Legacy alias.
    static var lookupOffset: Float { deviceOffset }

    /// User fine-tuning added on top of device offset.
    static var userAdjustment: Float {
        get {
            UserDefaults.standard.object(forKey: userAdjustmentKey) as? Float ?? 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userAdjustmentKey)
        }
    }

    /// dB_SPL = 20·log10(RMS) + deviceOffset + userAdjustment
    static var totalOffset: Float {
        deviceOffset + userAdjustment
    }

    static var weightingType: WeightingType {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weightingKey),
                  let type = WeightingType(rawValue: raw) else { return .a }
            return type
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: weightingKey)
        }
    }

    static var isHighSensitivityMode: Bool {
        get { UserDefaults.standard.bool(forKey: highSensitivityKey) }
        set { UserDefaults.standard.set(newValue, forKey: highSensitivityKey) }
    }

    static func calibrate(referenceSPL: Float, measuredDBFS: Float) {
        userAdjustment = referenceSPL - measuredDBFS - deviceOffset
    }

    static func resetCalibration() {
        userAdjustment = 0
    }
}
